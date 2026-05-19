## ADDED Requirements

### Requirement: 对话历史管理
系统 SHALL 维护对话历史列表，每条消息 SHALL 包含角色（system/user/assistant）、内容文本和时间戳。对话历史 SHALL 支持添加消息、清空对话、获取历史列表。

#### Scenario: 添加用户消息
- **WHEN** 用户发送一条消息 "你好"
- **THEN** 对话历史中新增一条 role=user, content="你好" 的消息

#### Scenario: 添加助手消息
- **WHEN** 模型生成回复 "你好！有什么可以帮你的？"
- **THEN** 对话历史中新增一条 role=assistant, content="你好！有什么可以帮你的？" 的消息

#### Scenario: 清空对话
- **WHEN** 调用 `clearHistory()`
- **THEN** 对话历史被清空，但保留系统提示词（如果存在）

### Requirement: 消息格式化
系统 SHALL 将对话历史格式化为符合模型 chat template 的 prompt 字符串。格式化 SHALL 正确处理 system、user、assistant 三种角色的标记。

#### Scenario: 格式化单轮对话
- **WHEN** 对话历史包含 [system: "你是助手", user: "你好"]
- **THEN** 生成的 prompt 字符串 SHALL 包含正确的角色标记和消息内容

#### Scenario: 格式化多轮对话
- **WHEN** 对话历史包含 system + 3 轮 user/assistant 交替消息
- **THEN** 生成的 prompt 字符串 SHALL 按时间顺序排列所有消息，且角色标记正确

### Requirement: 对话上下文截断
系统 SHALL 在对话历史过长时自动截断，确保总 token 数不超过模型上下文长度。截断 SHALL 保留最新的对话内容，优先丢弃最早的历史消息（系统提示词除外）。

#### Scenario: 上下文截断
- **WHEN** 对话历史累计 token 数超过模型最大上下文长度（如 2048）
- **THEN** 系统 SHALL 自动丢弃最早的用户/助手消息对，直到总 token 数在限制内
- **AND** 系统提示词 SHALL 始终保留

### Requirement: 流式回复接收
系统 SHALL 支持接收流式生成的回复，将每个 token 追加到当前助手消息中，并通知 UI 层更新。

#### Scenario: 流式回复追加
- **WHEN** 模型开始生成回复，第一个 token 是 "你"
- **THEN** 对话历史中新增一条 role=assistant, content="你" 的消息
- **WHEN** 下一个 token 是 "好"
- **THEN** 该消息内容更新为 "你好"

#### Scenario: 生成完成
- **WHEN** 模型生成完最后一个 token
- **THEN** 助手消息标记为完成状态，不再追加内容
