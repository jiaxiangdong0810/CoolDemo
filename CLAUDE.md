# CLAUDE.md

> **项目指令**：本项目不使用 superpowers 技能。不自动调用 brainstorming、writing-plans、test-driven-development、systematic-debugging 等流程。直接按用户指令执行，按需简化处理。

## 项目目标

一个 **Android + Flutter 混合项目**，核心目标是在手机端本地运行大语言模型（LLM），实现离线 AI 聊天对话。

**设计哲学**：原生 Android 仅作为"壳子"负责页面容器和权限管理，所有核心业务逻辑（模型推理、对话管理、UI）都在 Flutter 模块中实现，以便未来向 iOS / 桌面端复用。

**当前状态**：已实现最小可运行 Demo —— 端侧加载 Qwen GGUF 模型 + 多轮对话 + 流式输出。

---

## 整体架构（五层）

```
┌─────────────────────────────────────────────────────────────────┐
│  Layer 5: Flutter UI                                            │
│  ├─ ModelSetupPage   模型引导页（下载/导入/加载）                  │
│  ├─ ChatPage         聊天页（气泡、输入框、流式输出）               │
│  └─ First/SecondFlutterPage  原生混合导航演示页                   │
├─────────────────────────────────────────────────────────────────┤
│  Layer 4: Dart 业务逻辑                                          │
│  ├─ ChatService      对话历史管理、Prompt 格式化、上下文截断        │
│  ├─ ModelManager     模型文件下载、导入、校验、路径管理             │
│  └─ LlamaService     FFI 调用封装、Worker Isolate 调度            │
├─────────────────────────────────────────────────────────────────┤
│  Layer 3: FFI 桥接层（dart:ffi）                                  │
│  └─ llama_bindings.dart   C API → Dart 函数绑定                  │
├─────────────────────────────────────────────────────────────────┤
│  Layer 2: C++ Wrapper（Android .so）                             │
│  └─ llama_wrapper.cpp/h   简化 C API：load / generate / stream   │
├─────────────────────────────────────────────────────────────────┤
│  Layer 1: 推理引擎（llama.cpp）                                   │
│  └─ llama.cpp (submodule)  模型加载、tokenize、decode、sampling   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  GGUF 模型文件   │
                    │  (本地存储)      │
                    └─────────────────┘
```

---

## 关键架构决策

### 1. 为什么选择 llama.cpp + 自封装 FFI？

- **可控性**：不依赖 pub.dev 上维护状态不稳定的第三方包，版本和功能完全自主
- **跨平台**：一套 Dart 业务代码，各平台只需分别编译原生库（Android .so / iOS framework）
- **模型自由**：任何 GGUF 格式模型都能即插即用
- **开发量可控**：llama.cpp 的 C API 很简洁，核心只需封装 5-6 个函数

### 2. 为什么用 Worker Isolate 执行推理？

FFI 调用 C++ 函数是在 Dart 主线程同步执行的，而模型推理涉及大量矩阵计算。`LlamaService` 将 FFI 调用全部放在独立 worker isolate 中：

```
主 Isolate (UI 线程)
  │  SendPort 发送命令
  ▼
Worker Isolate (后台线程)
  │  执行 FFI → llama.cpp 推理
  │  流式 token 通过独立 ReceivePort 推回
  ▼
主 Isolate (回调更新 UI)
```

### 3. 原生层的职责边界

| 层级 | 负责 | 不负责 |
|------|------|--------|
| Android 原生 | Engine 预热、页面容器、存储权限申请、MethodChannel 路由 | 任何业务逻辑 |
| Flutter/Dart | UI、对话管理、模型管理、推理调用 | 底层矩阵运算、内存管理 |

---

## 数据流：一次聊天请求的路径

```
用户在 ChatPage 输入消息
        │
        ▼
ChatService.sendMessage()
  ├─ 添加用户消息到历史列表
  ├─ _buildPrompt()：按 Qwen chat template 格式化对话历史
  │   <|im_start|>system\n...<|im_end|>
  │   <|im_start|>user\n...<|im_end|>
  │   <|im_start|>assistant\n
  ├─ _truncateHistory()：上下文截断，保留最新消息
  │
  ▼
LlamaService.generateStream() ──SendPort──► Worker Isolate
                                              │
                                              ▼
                                          _workerStream()
                                            │ 调用 FFI
                                            ▼
                                          llama_generate_stream()
                                            │ 调用 C++ wrapper
                                            ▼
                                          llama_wrapper.cpp
                                            │ 调用 llama.cpp API
                                            ▼
                                          llama.cpp 推理引擎
                                            │ token 逐个生成
                                            ▼
                                          回调 → tokenPort.send(token)
                                              │
◄────────────────────────────────────── ReceivePort 接收 token
        │
        ▼
ChatService 更新消息内容 → notifyListeners()
        │
        ▼
ChatPage setState() → 流式显示新 token
```

---

## 模块职责

### Android 原生层

| 文件 | 职责 |
|------|------|
| `MyApplication` | 初始化 FlutterEngineGroup，预热默认 Engine |
| `FlutterEngineManager` | Engine 缓存管理（创建/复用/销毁） |
| `MainActivity` | 原生主页面，NavHost + Toolbar |
| `FirstFragment` | 首页 Fragment，提供两个入口按钮（普通 Flutter / AI 聊天），申请存储权限 |
| `CustomFlutterActivity` | 自定义 FlutterActivity，注册 MethodChannel 处理 `openNativeSecondPage` |
| `SecondActivity` | 原生第二个页面（演示 Flutter → 原生） |

### Flutter 层

| 文件 | 职责 |
|------|------|
| `main.dart` | App 入口，MethodChannel 定义，页面导航 |
| `model_setup_page.dart` | 模型引导：检测本地模型 → 下载 / 导入 → 加载 → 跳转聊天页 |
| `chat_page.dart` | 聊天 UI：消息气泡（Markdown 渲染）、输入框、流式加载状态 |
| `chat_service.dart` | 对话管理：消息列表、Qwen prompt 格式化、上下文截断、流式生成调度 |
| `llama_service.dart` | FFI 封装：worker isolate 管理、loadModel / generate / generateStream / chat |
| `model_manager.dart` | 模型文件：下载（带进度）、本地导入（流式复制）、校验、路径查找 |
| `llama_bindings.dart` | FFI 函数绑定：加载 `libllama_wrapper.so`，映射 C API |
| `log.dart` | 全局日志（logger 包） |

### C++ 原生层

| 文件 | 职责 |
|------|------|
| `llama_wrapper.h` | C API 头文件：6 个函数声明 |
| `llama_wrapper.cpp` | 实现：模型加载、tokenize、batch 构建、采样生成、流式回调、资源释放 |
| `llama.cpp/` | 第三方 submodule：llama.cpp 推理引擎源码 |
| `CMakeLists.txt` | 编译 llama.cpp 静态库 + 构建 `libllama_wrapper.so` |

---

## Prompt 格式化（Qwen Chat Template）

当前使用 Qwen 系列模型的 chat template 格式：

```
<|im_start|>system
你是一个有用的助手<|im_end|>
<|im_start|>user
你好<|im_end|>
<|im_start|>assistant
[模型在此处生成回复]
```

`ChatService._buildPrompt()` 负责将对话历史拼接成此格式，`ChatService._truncateHistory()` 在超出上下文长度时截断旧消息。

---

## 技术栈

| 层级 | 技术 |
|------|------|
| Android 原生 | Kotlin / Gradle / ViewBinding / FlutterEngineGroup |
| Flutter | Dart 3 / Material 3 |
| 状态管理 | ChangeNotifier（ChatService）|
| 端侧推理 | llama.cpp (C++) |
| Dart ↔ C++ | dart:ffi 手写绑定 |
| 模型格式 | GGUF |
| 聊天模板 | Qwen chat template |
| 依赖包 | ffi, path_provider, http, file_picker, flutter_markdown, logger |

---

## 注意事项

- 使用阿里云 Maven 镜像（`maven.aliyun.com`）
- NDK 仅编译 `arm64-v8a` ABI
- `flutter_boost` 已注释，当前未使用
- llama.cpp 作为 git submodule 位于 `app/src/main/cpp/llama.cpp/`
