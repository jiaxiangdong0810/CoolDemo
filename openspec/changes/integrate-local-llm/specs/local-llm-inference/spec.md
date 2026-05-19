## ADDED Requirements

### Requirement: 模型加载
系统 SHALL 提供通过 FFI 调用 llama.cpp 加载 GGUF 格式模型的能力。加载过程 SHALL 返回加载状态（成功/失败），失败时 SHALL 返回错误信息。

#### Scenario: 成功加载模型
- **WHEN** 调用 `loadModel(modelPath)` 且指定路径存在有效的 GGUF 文件
- **THEN** 模型加载成功，返回成功状态，系统进入可推理状态

#### Scenario: 加载不存在的模型文件
- **WHEN** 调用 `loadModel(modelPath)` 且指定路径不存在
- **THEN** 返回加载失败状态，错误信息包含 "模型文件不存在"

#### Scenario: 加载无效的模型文件
- **WHEN** 调用 `loadModel(modelPath)` 且文件存在但不是有效的 GGUF 格式
- **THEN** 返回加载失败状态，错误信息包含 "无效的模型文件"

### Requirement: 单轮文本生成
系统 SHALL 支持基于已加载模型进行单轮文本生成。输入一个 prompt 字符串，系统 SHALL 返回生成的文本。生成 SHALL 支持设置最大 token 数、温度等参数。

#### Scenario: 基本文本生成
- **WHEN** 模型已加载成功，调用 `generate("你好")`
- **THEN** 返回生成的文本字符串，且不为空

#### Scenario: 带参数的文本生成
- **WHEN** 调用 `generate("你好", maxTokens: 100, temperature: 0.7)`
- **THEN** 返回的文本长度不超过 100 个 token 的等效长度

#### Scenario: 未加载模型时生成
- **WHEN** 调用 `generate()` 但模型尚未加载
- **THEN** 抛出异常，提示 "模型未加载"

### Requirement: 流式文本生成
系统 SHALL 支持流式文本生成，通过回调函数逐 token 返回生成结果。每生成一个 token，SHALL 立即通过回调通知 Dart 层。

#### Scenario: 流式生成回调
- **WHEN** 调用 `generateStream("你好", onToken: (token) => ...)`
- **THEN** `onToken` 回调被多次调用，每次传递一个新生成的 token 字符串
- **AND** 所有 token 拼接起来等于完整生成结果

#### Scenario: 流式生成完成回调
- **WHEN** 流式生成完成（达到最大 token 数或生成结束标记）
- **THEN** `onComplete` 回调被调用，传递完整的生成文本

### Requirement: 多轮对话生成
系统 SHALL 支持多轮对话生成。接收对话历史列表（包含角色和消息内容），自动拼接成符合模型 chat template 的 prompt，然后生成回复。

#### Scenario: 多轮对话
- **WHEN** 调用 `chat(messages)`，其中 messages 包含系统提示词、用户历史消息和助手历史消息
- **THEN** 返回的回复 SHALL 考虑对话上下文，且格式符合 chat template

#### Scenario: 空对话历史
- **WHEN** 调用 `chat([])`（空列表）
- **THEN** 抛出异常，提示 "对话历史不能为空"

### Requirement: 资源释放
系统 SHALL 提供释放模型资源的能力。释放后 SHALL 清空所有模型相关的内存占用，系统回到未加载状态。

#### Scenario: 正常释放资源
- **WHEN** 调用 `dispose()` 且模型已加载
- **THEN** 模型资源被释放，内存占用恢复到加载前水平
- **AND** 再次调用 `generate()` 时抛出 "模型未加载" 异常

#### Scenario: 重复释放
- **WHEN** 调用 `dispose()` 但模型未加载
- **THEN** 静默返回，不抛出异常
