import '../models/chat_message.dart';
import '../models/session_meta.dart';

/// 单会话完整数据（持久化用）
class SessionData {
  final SessionMeta meta;
  final List<ChatMessage> messages;

  SessionData({required this.meta, required this.messages});

  Map<String, dynamic> toJson() => {
        'meta': meta.toJson(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory SessionData.fromJson(Map<String, dynamic> json) {
    return SessionData(
      meta: SessionMeta.fromJson(json['meta'] as Map<String, dynamic>),
      messages: (json['messages'] as List<dynamic>)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 聊天记录存储抽象接口
abstract class ChatStorage {
  /// 加载所有会话元数据列表（按 updatedAt 倒序）
  Future<List<SessionMeta>> loadSessionList();

  /// 加载单个会话的完整数据
  Future<SessionData?> loadSession(String sessionId);

  /// 保存会话（含元数据和消息列表）
  Future<void> saveSession(SessionData data);

  /// 删除会话
  Future<void> deleteSession(String sessionId);

  /// 保存会话列表元数据
  Future<void> saveSessionList(List<SessionMeta> metas);
}
