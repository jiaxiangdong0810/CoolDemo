import 'dart:async';

import 'package:flutter/foundation.dart';

import 'llama_service.dart';

/// 消息角色
enum MessageRole { system, user, assistant }

/// 聊天消息数据模型
class ChatMessage {
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final bool isComplete;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isComplete = true,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    bool? isComplete,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// 聊天服务 - 管理对话历史、消息格式化、调用 LlamaService 生成回复
class ChatService extends ChangeNotifier {
  final LlamaService _llamaService;

  ChatService({LlamaService? llamaService})
      : _llamaService = llamaService ?? LlamaService();

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  String? _systemPrompt;
  String? get systemPrompt => _systemPrompt;

  static const int _maxContextTokens = 2048;
  static const int _maxResponseTokens = 512;

  /// 设置系统提示词
  void setSystemPrompt(String prompt) {
    _systemPrompt = prompt;
    notifyListeners();
  }

  /// 添加一条消息
  void addMessage(ChatMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  /// 获取对话历史
  List<ChatMessage> getHistory() => List.unmodifiable(_messages);

  /// 清空对话历史（保留系统提示词）
  void clearHistory() {
    _messages.clear();
    notifyListeners();
  }

  /// 发送用户消息并获得回复（流式）
  Future<void> sendMessage(String userMessage) async {
    if (userMessage.trim().isEmpty) return;

    // 添加用户消息
    addMessage(ChatMessage(role: MessageRole.user, content: userMessage.trim()));

    _isGenerating = true;
    notifyListeners();

    try {
      // 构建格式化的 prompt
      final prompt = _buildPrompt();

      // 创建占位助手消息
      final assistantMessage = ChatMessage(
        role: MessageRole.assistant,
        content: '',
        isComplete: false,
      );
      addMessage(assistantMessage);
      final assistantIndex = _messages.length - 1;

      // 流式生成
      final buffer = StringBuffer();
      await _llamaService.generateStream(
        prompt,
        onToken: (token) {
          buffer.write(token);
          _messages[assistantIndex] = assistantMessage.copyWith(
            content: buffer.toString(),
          );
          notifyListeners();
        },
        maxTokens: _maxResponseTokens,
        temperature: 0.7,
      );

      // 标记完成
      _messages[assistantIndex] = assistantMessage.copyWith(
        content: buffer.toString(),
        isComplete: true,
      );
    } catch (e) {
      // 替换失败的助手消息为错误提示
      if (_messages.isNotEmpty && _messages.last.role == MessageRole.assistant) {
        _messages[_messages.length - 1] = ChatMessage(
          role: MessageRole.assistant,
          content: '生成失败: $e',
          isComplete: true,
        );
      }
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// 将对话历史格式化为 Qwen chat template 格式的 prompt
  String _buildPrompt() {
    final buffer = StringBuffer();

    // 系统提示词
    if (_systemPrompt != null && _systemPrompt!.isNotEmpty) {
      buffer.writeln('<|im_start|>system');
      buffer.writeln(_systemPrompt);
      buffer.writeln('<|im_end|>');
    }

    // 截断后的对话历史
    final truncatedMessages = _truncateHistory();

    for (final msg in truncatedMessages) {
      switch (msg.role) {
        case MessageRole.user:
          buffer.writeln('<|im_start|>user');
          buffer.writeln(msg.content);
          buffer.writeln('<|im_end|>');
        case MessageRole.assistant:
          buffer.writeln('<|im_start|>assistant');
          buffer.writeln(msg.content);
          buffer.writeln('<|im_end|>');
        case MessageRole.system:
          // 已在上方处理
          break;
      }
    }

    // 添加 assistant 前缀，引导模型生成回复
    buffer.write('<|im_start|>assistant\n');

    return buffer.toString();
  }

  /// 上下文截断：保留系统提示词和最新的对话
  List<ChatMessage> _truncateHistory() {
    // 简单策略：估计每个消息约 50-200 tokens
    // 保留 system prompt + 最近的消息对，直到接近上下文限制
    const estimatedTokensPerMessage = 100;
    const maxMessages = (_maxContextTokens - _maxResponseTokens) ~/ estimatedTokensPerMessage;

    // 过滤掉系统消息（已单独处理）和未完成的助手消息
    final historyMessages = _messages
        .where((m) => m.role != MessageRole.system && m.isComplete)
        .toList();

    if (historyMessages.length <= maxMessages) {
      return historyMessages;
    }

    // 保留最新的消息
    return historyMessages.sublist(historyMessages.length - maxMessages);
  }

  @override
  void dispose() {
    _llamaService.dispose();
    super.dispose();
  }
}
