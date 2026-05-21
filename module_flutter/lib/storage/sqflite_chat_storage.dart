import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/chat_message.dart';
import '../models/session_meta.dart';
import 'chat_storage.dart';

/// SQLite 实现的聊天记录存储
///
/// 表结构：
/// - sessions: 会话元数据
/// - messages: 消息列表，外键关联 sessions
///
/// 写入策略：追加消息时只做 INSERT，但 saveSession 为简单正确采用
/// 事务内 REPLACE sessions + DELETE messages + INSERT messages（全量覆盖）。
class SqfliteChatStorage implements ChatStorage {
  Database? _db;

  Future<Database> get _database async {
    _db ??= await _initDb();
    return _db!;
  }

  static const String _dbName = 'chat.db';
  static const int _dbVersion = 1;

  static const String _tSessions = 'sessions';
  static const String _colSId = 'id';
  static const String _colSTitle = 'title';
  static const String _colSCreatedAt = 'created_at';
  static const String _colSUpdatedAt = 'updated_at';
  static const String _colSMsgCount = 'message_count';

  static const String _tMessages = 'messages';
  static const String _colMId = 'id';
  static const String _colMSessionId = 'session_id';
  static const String _colMRole = 'role';
  static const String _colMContent = 'content';
  static const String _colMTimestamp = 'timestamp';
  static const String _colMIsComplete = 'is_complete';

  Future<Database> _initDb() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDir.path, _dbName);

    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tSessions (
            $_colSId TEXT PRIMARY KEY,
            $_colSTitle TEXT,
            $_colSCreatedAt TEXT,
            $_colSUpdatedAt TEXT,
            $_colSMsgCount INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE $_tMessages (
            $_colMId TEXT PRIMARY KEY,
            $_colMSessionId TEXT NOT NULL,
            $_colMRole TEXT NOT NULL,
            $_colMContent TEXT NOT NULL,
            $_colMTimestamp TEXT NOT NULL,
            $_colMIsComplete INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_msg_session ON $_tMessages($_colMSessionId)
        ''');
      },
    );
  }

  @override
  Future<List<SessionMeta>> loadSessionList() async {
    final db = await _database;
    final rows = await db.query(_tSessions);

    return rows.map((r) {
      return SessionMeta(
        id: r[_colSId] as String,
        title: r[_colSTitle] as String? ?? '',
        createdAt: DateTime.parse(r[_colSCreatedAt] as String),
        updatedAt: DateTime.parse(r[_colSUpdatedAt] as String),
        messageCount: r[_colSMsgCount] as int? ?? 0,
      );
    }).toList();
  }

  @override
  Future<SessionData?> loadSession(String sessionId) async {
    final db = await _database;

    final sessionRows = await db.query(
      _tSessions,
      where: '$_colSId = ?',
      whereArgs: [sessionId],
    );
    if (sessionRows.isEmpty) return null;

    final meta = SessionMeta(
      id: sessionRows.first[_colSId] as String,
      title: sessionRows.first[_colSTitle] as String? ?? '',
      createdAt: DateTime.parse(sessionRows.first[_colSCreatedAt] as String),
      updatedAt: DateTime.parse(sessionRows.first[_colSUpdatedAt] as String),
      messageCount: sessionRows.first[_colSMsgCount] as int? ?? 0,
    );

    final msgRows = await db.query(
      _tMessages,
      where: '$_colMSessionId = ?',
      whereArgs: [sessionId],
    );

    final messages = msgRows.map((r) => ChatMessage(
      id: r[_colMId] as String,
      role: MessageRole.values.byName(r[_colMRole] as String),
      content: r[_colMContent] as String,
      timestamp: DateTime.parse(r[_colMTimestamp] as String),
      isComplete: (r[_colMIsComplete] as int) == 1,
    )).toList();

    return SessionData(meta: meta, messages: messages);
  }

  @override
  Future<void> saveSession(SessionData data) async {
    final db = await _database;
    await db.transaction((txn) async {
      // 1. 先清理旧消息（避免外键约束冲突）
      await txn.delete(
        _tMessages,
        where: '$_colMSessionId = ?',
        whereArgs: [data.meta.id],
      );

      // 2. 更新或插入会话元数据（不用 REPLACE，避免外键问题）
      final updated = await txn.update(
        _tSessions,
        {
          _colSTitle: data.meta.title,
          _colSCreatedAt: data.meta.createdAt.toIso8601String(),
          _colSUpdatedAt: data.meta.updatedAt.toIso8601String(),
          _colSMsgCount: data.messages.length,
        },
        where: '$_colSId = ?',
        whereArgs: [data.meta.id],
      );
      if (updated == 0) {
        await txn.insert(_tSessions, {
          _colSId: data.meta.id,
          _colSTitle: data.meta.title,
          _colSCreatedAt: data.meta.createdAt.toIso8601String(),
          _colSUpdatedAt: data.meta.updatedAt.toIso8601String(),
          _colSMsgCount: data.messages.length,
        });
      }

      // 3. 插入所有消息
      for (final msg in data.messages) {
        await txn.insert(_tMessages, {
          _colMId: msg.id,
          _colMSessionId: data.meta.id,
          _colMRole: msg.role.name,
          _colMContent: msg.content,
          _colMTimestamp: msg.timestamp.toIso8601String(),
          _colMIsComplete: msg.isComplete ? 1 : 0,
        });
      }
    });
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final db = await _database;
    await db.delete(
      _tMessages,
      where: '$_colMSessionId = ?',
      whereArgs: [sessionId],
    );
    await db.delete(
      _tSessions,
      where: '$_colSId = ?',
      whereArgs: [sessionId],
    );
  }

  @override
  Future<void> saveSessionList(List<SessionMeta> metas) async {
    final db = await _database;
    await db.transaction((txn) async {
      for (final meta in metas) {
        await txn.update(
          _tSessions,
          {
            _colSTitle: meta.title,
            _colSUpdatedAt: meta.updatedAt.toIso8601String(),
            _colSMsgCount: meta.messageCount,
          },
          where: '$_colSId = ?',
          whereArgs: [meta.id],
        );
      }
    });
  }
}
