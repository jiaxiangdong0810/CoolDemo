## 1. 项目配置与依赖

- [x] 1.1 在 Flutter 模块 `pubspec.yaml` 中添加 `ffi`、`path_provider`、`http` 依赖
- [x] 1.2 在 Android 项目 `app/build.gradle.kts` 中配置 CMake/NDK 构建支持
- [x] 1.3 创建 `app/src/main/cpp/CMakeLists.txt`，配置 llama.cpp 编译规则
- [x] 1.4 在 `app/build.gradle.kts` 中配置 `externalNativeBuild` 和 `ndk` 的 abiFilters（arm64-v8a）

## 2. 编译 llama.cpp 原生库

- [x] 2.1 将 llama.cpp 源码以子模块方式引入 `app/src/main/cpp/llama.cpp/`
- [x] 2.2 编写精简的 C API 封装层（`llama_wrapper.cpp` / `llama_wrapper.h`），暴露加载、生成、释放等函数
- [ ] 2.3 运行 Gradle 构建，确认 `libllama.so` 成功编译并打包到 APK（需要 NDK 环境）
- [ ] 2.4 在设备上验证 .so 文件可用（通过 `DynamicLibrary.open` 加载不报错）（需要 NDK 环境）

## 3. Dart FFI 绑定层

- [x] 3.1 创建 `module_flutter/lib/ffi/llama_bindings.dart`，定义 C 函数的 Dart 类型签名
- [x] 3.2 实现 `DynamicLibrary.open('libllama_wrapper.so')` 加载逻辑，处理平台差异
- [x] 3.3 绑定核心 C API 函数：`llama_load_model`、`llama_generate`、`llama_generate_stream`、`llama_free_model`
- [ ] 3.4 编写 FFI 层单元测试（验证函数绑定正确，无需实际模型）

## 4. Dart 服务层 - LlamaService

- [x] 4.1 创建 `module_flutter/lib/services/llama_service.dart`，封装 FFI 调用
- [x] 4.2 实现 `loadModel(modelPath)`：加载模型并管理加载状态
- [x] 4.3 实现 `generate(prompt)`：单轮文本生成
- [x] 4.4 实现 `generateStream(prompt, onToken)`：流式文本生成（使用 `NativeCallable`）
- [x] 4.5 实现 `chat(messages)`：多轮对话生成，自动拼接 chat template
- [x] 4.6 实现 `dispose()`：释放模型资源，清理 Pointer
- [x] 4.7 处理异常状态：未加载模型时调用生成、加载失败等场景

## 5. Dart 服务层 - ChatService

- [x] 5.1 创建 `module_flutter/lib/services/chat_service.dart`，定义 `ChatMessage` 数据模型（role/content/timestamp）
- [x] 5.2 实现对话历史管理：`addMessage()`、`clearHistory()`、`getHistory()`
- [x] 5.3 实现消息格式化：将 `List<ChatMessage>` 转换为 Qwen chat template 格式的 prompt 字符串
- [x] 5.4 实现上下文截断策略：当对话历史过长时，丢弃最早的消息对（保留 system prompt）
- [x] 5.5 集成流式生成：在 `sendMessage()` 中调用 `LlamaService.generateStream()`，逐 token 更新当前助手消息
- [x] 5.6 集成状态管理：使用 `ChangeNotifier` 管理对话状态和生成状态（功能等价于 Riverpod）

## 6. Dart 服务层 - ModelManager

- [x] 6.1 创建 `module_flutter/lib/services/model_manager.dart`
- [x] 6.2 实现模型下载：`downloadModel(url, onProgress)`，使用 `http` 包分块下载，存储到 `path_provider` 获取的应用私有目录
- [x] 6.3 实现下载取消：`cancelDownload()`，中断下载并清理部分文件
- [x] 6.4 实现模型校验：`validateModel(path)`，检查文件存在性和大小
- [x] 6.5 实现下载进度追踪：`getDownloadProgress()` 返回进度和状态
- [x] 6.6 实现模型路径管理：`getModelPath(modelName)`、`isModelAvailable(modelName)`

## 7. 聊天 UI 层

- [x] 7.1 创建 `module_flutter/lib/pages/chat_page.dart` 作为主聊天页面
- [x] 7.2 实现消息列表：`ListView.builder` 展示对话历史，用户消息右对齐、助手消息左对齐
- [x] 7.3 实现消息气泡组件：区分用户/助手样式，支持 Markdown 基础渲染（粗体、代码块、列表）
- [x] 7.4 实现输入区域：`TextField`（多行）+ 发送按钮，发送后清空输入框
- [x] 7.5 实现发送状态管理：生成中时禁用输入框、显示加载动画
- [x] 7.6 实现空对话状态：显示欢迎语或提示信息
- [x] 7.7 实现加载状态覆盖层：`ModelSetupPage` 处理模型加载中/下载中状态

## 8. 页面导航与集成

- [x] 8.1 在原生 `FirstFragment` 中添加入口，跳转到聊天 Flutter 页面
- [x] 8.2 在 Flutter 侧注册聊天页面路由（`main.dart` 中通过 `MaterialPageRoute`）
- [ ] 8.3 确保 Flutter Engine 预热时包含聊天页面所需的初始资源（非关键，使用默认 Engine）

## 9. 模型准备与验证

- [ ] 9.1 下载 Qwen 2.5 0.5B Instruct Q4_0 GGUF 模型文件到本地（需要运行环境）
- [ ] 9.2 将模型文件放入设备应用目录（首次可通过 adb push 或应用内下载）（需要运行环境）
- [ ] 9.3 运行完整链路验证：加载模型 → 输入"你好" → 确认返回中文回复（需要运行环境）
- [ ] 9.4 测试流式输出：观察文字是否逐字出现（需要运行环境）
- [ ] 9.5 测试多轮对话：确认上下文记忆正常（需要运行环境）

## 10. 调试与优化

- [ ] 10.1 使用 `logcat` 和 Flutter DevTools 检查内存占用，确认模型加载后的内存增长（需要运行环境）
- [ ] 10.2 测试异常情况：模型文件不存在、加载失败、生成超时等，确认错误提示友好（需要运行环境）
- [ ] 10.3 测试低端设备：在内存较少的设备上运行，检查是否出现 OOM（需要运行环境）
- [ ] 10.4 优化首次启动体验：如果模型未下载，显示下载引导页面而非直接报错（已实现基础版本）
