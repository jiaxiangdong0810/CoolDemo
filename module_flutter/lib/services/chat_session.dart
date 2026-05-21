import 'dart:async';

import '../models/chat_message.dart';
import '../prompts/system_prompts.dart';
import '../utils/log.dart';
import 'llama_service.dart';

/// 单会话逻辑 - 管理一个对话的消息列表和生成过程
///
/// 职责：
/// - 维护本会话的消息列表
/// - Prompt 格式化、上下文截断
/// - 调用 LlamaService 生成回复
/// - 标题生成（第一条用户消息前20字）
///
/// 不继承 ChangeNotifier，不感知持久化，不感知其他会话存在。
/// 状态变更通过 [onUpdated] 回调通知外部。
class ChatSession {
  final String id;
  String? _title;
  final DateTime createdAt;
  DateTime _updatedAt;
  final List<ChatMessage> _messages = [];
  bool _isGenerating = false;
  String? _systemPrompt;

  // 上下文限制
  static const int _maxContextTokens = 2048;
  static const int _maxResponseTokens = 512;

  ChatSession._({
    required this.id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? systemPrompt,
    List<ChatMessage>? messages,
  })  : _title = title,
        createdAt = createdAt ?? DateTime.now(),
        _updatedAt = updatedAt ?? DateTime.now(),
        _systemPrompt = systemPrompt ?? SystemPrompts.defaultQA {
    if (messages != null) {
      _messages.addAll(messages);
    }
  }

  factory ChatSession.create() => ChatSession._(id: _generateId());

  // ========== 状态查询 ==========

  String get title => _title ?? '新对话';

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool get isGenerating => _isGenerating;

  bool get isEmpty => _messages.isEmpty;

  bool get hasUserMessage => _messages.any((m) => m.role == MessageRole.user);

  DateTime get updatedAt => _updatedAt;

  int get messageCount => _messages.length;

  // ========== 核心：发送消息并流式生成 ==========

  Future<void> sendMessage(
    String text,
    LlamaService llamaService, {
    required void Function() onUpdated,
  }) async {
    if (text.trim().isEmpty) return;

    final trimmed = text.trim();

    // 添加用户消息
    _addUserMessage(trimmed);
    _updatedAt = DateTime.now();
    onUpdated();

    _isGenerating = true;
    onUpdated();

    try {
      final prompt = _buildPrompt();

      LogByLLM.d('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      LogByLLM.d('【用户发送】$trimmed');
      LogByLLM.d('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      LogByLLM.d('【完整上下文 Prompt】\n$prompt');
      LogByLLM.d('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // 创建占位助手消息
      final assistantMessage = ChatMessage(
        role: MessageRole.assistant,
        content: '',
        isComplete: false,
      );
      _messages.add(assistantMessage);
      final assistantIndex = _messages.length - 1;
      onUpdated();

      // 流式生成
      final buffer = StringBuffer();
      await llamaService.generateStream(
        prompt,
        onToken: (token) {
          buffer.write(token);
          _messages[assistantIndex] = assistantMessage.copyWith(
            content: buffer.toString(),
          );
          onUpdated();
          LogByLLM.d('【LLM Token】$token');
        },
        maxTokens: _maxResponseTokens,
        temperature: 0.7,
      );

      // 标记完成
      _messages[assistantIndex] = assistantMessage.copyWith(
        content: buffer.toString(),
        isComplete: true,
      );
      _updatedAt = DateTime.now();

      LogByLLM.d('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      LogByLLM.d('【LLM 完整回复】${buffer.toString()}');
      LogByLLM.d('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e) {
      if (_messages.isNotEmpty && _messages.last.role == MessageRole.assistant) {
        _messages[_messages.length - 1] = ChatMessage(
          role: MessageRole.assistant,
          content: '生成失败: $e',
          isComplete: true,
        );
      }
    } finally {
      _isGenerating = false;
      onUpdated();
    }
  }

  /// 停止当前生成
  void stopGeneration(LlamaService llamaService) {
    if (!_isGenerating) return;
    llamaService.stopGeneration();
  }

  /// 清空本会话消息（保留系统提示词）
  void clearMessages() {
    _messages.clear();
    _title = null;
    _updatedAt = DateTime.now();
  }

  // ========== Prompt 构建与截断 ==========

  String _buildPrompt() {
    final buffer = StringBuffer();

    if (_systemPrompt != null && _systemPrompt!.isNotEmpty) {
      buffer.writeln('<|im_start|>system');
      buffer.writeln(_systemPrompt);
      buffer.writeln('<|im_end|>');
    }

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
          break;
      }
    }

    buffer.write('<|im_start|>assistant\n');
    return buffer.toString();
  }

  List<ChatMessage> _truncateHistory() {
    const estimatedTokensPerMessage = 100;
    const maxMessages = (_maxContextTokens - _maxResponseTokens) ~/ estimatedTokensPerMessage;

    final historyMessages = _messages
        .where((m) => m.role != MessageRole.system && m.isComplete)
        .toList();

    if (historyMessages.length <= maxMessages) {
      return historyMessages;
    }
    return historyMessages.sublist(historyMessages.length - maxMessages);
  }

  // ========== 内部工具 ==========

  void _addUserMessage(String text) {
    _messages.add(ChatMessage(role: MessageRole.user, content: text));
    if (_title == null) {
      _title = _generateTitle(text);
    }
  }

  static String _generateTitle(String firstUserMessage) {
    if (firstUserMessage.length <= 20) return firstUserMessage;
    return '${firstUserMessage.substring(0, 20)}...';
  }

  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // ========== 序列化 ==========

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': _title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': _updatedAt.toIso8601String(),
        'systemPrompt': _systemPrompt,
        'messages': _messages.map((m) => m.toJson()).toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession._(
      id: json['id'] as String,
      title: json['title'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      systemPrompt: json['systemPrompt'] as String?,
      messages: (json['messages'] as List<dynamic>?)
          ?.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
