import 'package:flutter/foundation.dart';

import '../models/session_meta.dart';
import '../storage/chat_storage.dart';
import '../storage/sqflite_chat_storage.dart';
import 'chat_session.dart';
import 'llama_service.dart';

/// 会话管理器 - 管理多个 ChatSession 的生命周期、历史列表、持久化
///
/// 职责：
/// - 维护历史会话列表和当前激活会话
/// - 新开会话、切换会话、删除会话
/// - 切换时自动 stop 当前生成
/// - 调度持久化（MMKV）
/// - 作为唯一 ChangeNotifier，供 UI 监听
class ChatSessionManager extends ChangeNotifier {
  final LlamaService _llamaService;
  final ChatStorage _storage;

  ChatSessionManager({
    required LlamaService llamaService,
    ChatStorage? storage,
  })  : _llamaService = llamaService,
        _storage = storage ?? SqfliteChatStorage();

  final List<ChatSession> _sessions = [];
  ChatSession? _currentSession;

  bool _initialized = false;

  // ========== 状态查询 ==========

  List<ChatSession> get sessions => List.unmodifiable(_sessions);

  ChatSession? get currentSession => _currentSession;

  bool get isGenerating => _currentSession?.isGenerating ?? false;

  /// 当前是否可以开启新对话（当前会话已有用户消息，或当前为空）
  bool get canStartNewSession {
    if (_currentSession == null) return true;
    return _currentSession!.hasUserMessage;
  }

  /// 当前是否已经是全新的空对话
  bool get isCurrentSessionEmpty {
    return _currentSession != null && !_currentSession!.hasUserMessage;
  }

  // ========== 初始化 ==========

  /// 异步初始化：从存储加载历史会话列表
  Future<void> init() async {
    if (_initialized) return;

    final metas = await _storage.loadSessionList();
    _sessions.clear();

    for (final meta in metas) {
      final data = await _storage.loadSession(meta.id);
      if (data != null) {
        _sessions.add(ChatSession.fromJson({
          'id': data.meta.id,
          'title': data.meta.title,
          'createdAt': data.meta.createdAt.toIso8601String(),
          'updatedAt': data.meta.updatedAt.toIso8601String(),
          'messages': data.messages.map((m) => m.toJson()).toList(),
        }));
      }
    }

    // 如果没有历史会话，自动创建一个空会话
    if (_sessions.isEmpty) {
      _currentSession = ChatSession.create();
      _sessions.add(_currentSession!);
    } else {
      _currentSession = _sessions.first;
    }

    _initialized = true;
    notifyListeners();
  }

  // ========== 会话操作 ==========

  /// 开启新对话
  ///
  /// 如果当前已经是空对话（无用户消息），则直接返回当前会话，不创建新的。
  ChatSession startNewSession() {
    // 防重复：当前已经是空会话，直接返回
    if (isCurrentSessionEmpty) {
      return _currentSession!;
    }

    // 保存当前会话
    _persistSession(_currentSession!);

    // 创建新会话并置顶
    final newSession = ChatSession.create();
    _sessions.insert(0, newSession);
    _currentSession = newSession;

    notifyListeners();
    return newSession;
  }

  /// 切换到指定历史会话
  ///
  /// 切换前会自动停止当前会话的生成。
  Future<void> switchSession(String sessionId) async {
    if (_currentSession?.id == sessionId) return;

    // 1. 停止当前生成
    if (_currentSession != null && _currentSession!.isGenerating) {
      _currentSession!.stopGeneration(_llamaService);
      // 等待一小段时间确保生成彻底停止
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // 2. 保存当前会话
    if (_currentSession != null) {
      await _persistSession(_currentSession!);
    }

    // 3. 查找目标会话
    final target = _sessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => throw ArgumentError('Session not found: $sessionId'),
    );

    _currentSession = target;
    notifyListeners();
  }

  /// 删除历史会话
  Future<void> deleteSession(String sessionId) async {
    // 不能删除当前激活的会话
    if (_currentSession?.id == sessionId) {
      // 如果当前会话有消息，先保存再清空；如果无消息，直接允许删除
      if (_currentSession!.hasUserMessage) {
        // 不允许删除有内容的当前会话，或者先清空
        return;
      }
    }

    _sessions.removeWhere((s) => s.id == sessionId);
    await _storage.deleteSession(sessionId);

    // 如果删光了，自动创建一个空会话
    if (_sessions.isEmpty) {
      _currentSession = ChatSession.create();
      _sessions.add(_currentSession!);
    } else if (_currentSession?.id == sessionId) {
      _currentSession = _sessions.first;
    }

    notifyListeners();
  }

  /// 发送消息 - 委托给当前会话
  Future<void> sendMessage(String text) async {
    if (_currentSession == null) return;

    await _currentSession!.sendMessage(
      text,
      _llamaService,
      onUpdated: notifyListeners,
    );

    // 生成完成后持久化
    await _persistSession(_currentSession!);
  }

  /// 停止当前生成
  void stopGeneration() {
    _currentSession?.stopGeneration(_llamaService);
  }

  /// 清空当前会话
  void clearCurrentSession() {
    if (_currentSession == null) return;
    _currentSession!.clearMessages();
    notifyListeners();
  }

  // ========== 持久化 ==========

  Future<void> _persistSession(ChatSession session) async {
    final data = SessionData(
      meta: SessionMeta(
        id: session.id,
        title: session.title,
        createdAt: session.createdAt,
        updatedAt: DateTime.now(),
        messageCount: session.messageCount,
      ),
      messages: session.messages,
    );
    await _storage.saveSession(data);
  }

  @override
  void dispose() {
    // 退出前保存当前会话
    if (_currentSession != null) {
      _persistSession(_currentSession!);
    }
    super.dispose();
  }
}
