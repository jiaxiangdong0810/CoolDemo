import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../services/chat_session.dart';
import '../../services/chat_session_manager.dart';

/// 聊天侧边栏 - 历史会话列表
///
/// 第一项固定为"开启新对话"，下面是历史会话列表。
class ChatDrawer extends StatelessWidget {
  final ChatSessionManager sessionManager;
  final VoidCallback onClose;

  const ChatDrawer({
    super.key,
    required this.sessionManager,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final sessions = sessionManager.sessions;
    final currentSession = sessionManager.currentSession;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // 头部
            _buildHeader(context),
            const Divider(height: 1),
            // 列表
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: sessions.length + 1, // +1 为"开启新对话"
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildNewChatTile(context);
                  }
                  final session = sessions[index - 1];
                  final isActive = session.id == currentSession?.id;
                  return _buildSessionTile(context, session, isActive);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          const Text(
            '历史对话',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  /// "开启新对话" 项
  Widget _buildNewChatTile(BuildContext context) {
    final isEmpty = sessionManager.isCurrentSessionEmpty;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.add_comment,
          color: Colors.green.shade600,
        ),
      ),
      title: const Text(
        '开启新对话',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: isEmpty
          ? Text(
              '当前已是新对话',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            )
          : null,
      onTap: () {
        sessionManager.startNewSession();
        onClose();
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  /// 单个历史会话项
  Widget _buildSessionTile(
    BuildContext context,
    ChatSession session,
    bool isActive,
  ) {
    final userMsgCount =
        session.messages.where((m) => m.role == MessageRole.user).length;
    final timeStr = _formatTime(session.updatedAt);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border.all(color: Colors.blue.shade300, width: 1.5)
              : null,
        ),
        child: Icon(
          Icons.chat_bubble_outline,
          color: isActive ? Colors.blue.shade600 : Colors.grey.shade600,
          size: 20,
        ),
      ),
      title: Text(
        session.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          color: isActive ? Colors.blue.shade800 : null,
        ),
      ),
      subtitle: Text(
        '$userMsgCount 条消息 · $timeStr',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
        ),
      ),
      trailing: isActive
          ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.blue.shade400,
                shape: BoxShape.circle,
              ),
            )
          : null,
      selected: isActive,
      selectedTileColor: Colors.blue.shade50.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      onTap: () {
        if (!isActive) {
          sessionManager.switchSession(session.id);
        }
        onClose();
      },
      // 长按删除（仅限非当前会话）
      onLongPress: isActive
          ? null
          : () => _confirmDelete(context, session),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ChatSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('确定删除 "${session.title}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await sessionManager.deleteSession(session.id);
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    if (time.year == now.year) {
      return '${time.month}月${time.day}日';
    }
    return '${time.year}年${time.month}月${time.day}日';
  }
}
