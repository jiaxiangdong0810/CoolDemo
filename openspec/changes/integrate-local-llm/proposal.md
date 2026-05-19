# 端侧 LLM 集成方案

## Why

当前项目的 Flutter 模块仅实现了原生页面跳转，缺乏核心功能。为了让产品具备真正的 AI 能力，需要让 Flutter 在设备本地运行大语言模型，实现不依赖网络的聊天对话功能。端侧运行不仅保障用户隐私数据不出设备，还能在无网络环境下正常使用，同时降低长期运营成本。

## What Changes

- **新增原生库编译流程**：基于 llama.cpp 源码编译 Android arm64-v8a 的 `libllama.so`
- **新增 Dart FFI 绑定层**：通过 `dart:ffi` 调用 llama.cpp 的 C API（模型加载、token 生成、资源释放）
- **新增 Dart 服务层**：封装 `LlamaService`，提供 `loadModel()`、`generate()`、`chat()` 等 Dart 友好的 API
- **新增聊天对话模块**：实现对话历史管理、流式输出、消息气泡 UI
- **新增模型管理**：支持模型文件下载、本地存储路径管理、加载状态检测
- **新增 Gradle 构建配置**：将原生库编译集成到 Android 构建流程

## Capabilities

### New Capabilities

- `local-llm-inference`：本地大语言模型推理引擎。负责模型加载、文本生成、流式输出、资源管理。核心能力包括：通过 FFI 调用 llama.cpp 进行 token 生成，支持单轮对话和多轮对话的 prompt 拼接，支持逐 token 回调的流式输出。
- `chat-service`：聊天对话服务。负责对话状态管理、消息存储、历史记录拼接。核心能力包括：对话历史维护、消息格式化（支持系统提示词、用户消息、助手消息的角色标记）、对话上下文截断策略。
- `model-management`：模型文件管理。负责模型文件的下载、校验、本地路径管理。核心能力包括：从网络下载 GGUF 格式模型文件、存储到应用私有目录、检测模型可用性、计算下载进度。
- `chat-ui`：聊天界面。负责消息展示、输入交互、加载状态。核心能力包括：消息气泡列表、Markdown 富文本渲染、输入框与发送按钮、生成中的加载动画。

### Modified Capabilities

- （无现有 spec 需要修改）

## Impact

- **Android 原生层**：新增 CMake 构建配置编译 llama.cpp，新增 NDK 相关构建步骤
- **Flutter 模块**：新增 FFI 绑定代码、服务层代码、UI 层代码、状态管理代码
- **构建系统**：Gradle 配置需添加 CMake/NDK 支持，Flutter 模块的 `pubspec.yaml` 需新增依赖
- **包体积**：增加约 2-5MB 的 libllama.so 库文件
- **运行时内存**：加载模型后额外占用约 500MB-2GB 内存（取决于模型大小）
- **设备要求**：minSdk 保持 24，但端侧 LLM 实际运行需要 arm64 设备且内存 >= 4GB
