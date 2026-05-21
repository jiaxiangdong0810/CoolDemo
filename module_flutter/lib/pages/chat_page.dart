import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../providers/chat_providers.dart';
import '../widgets/assistant_message_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/user_message_bubble.dart';
import 'widgets/chat_drawer.dart';

/// 聊天主页面
///
/// 性能优化要点：
/// 1. 使用 Riverpod 细粒度 Provider，每个组件只监听自己关心的数据切片
/// 2. [isGeneratingProvider]（bool）→ ChatInputBar 只在生成开始/结束时重建，
///    流式输出期间逐 token 不重建
/// 3. [currentMessagesProvider] → _MessageList 每次 token 重建（内容确实变了）
/// 4. [currentSessionTitleProvider] / [hasMessagesProvider] → AppBar 低频重建
/// 5. 每条消息使用 [ValueKey] + [RepaintBoundary] 减少 diff 和重绘开销
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _showQuickPhrases = false;

  final List<String> _quickPhrases = [
    '你好',
    '写一个java中的最优的单例子模式 使用markdown格式',
    '再见',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final sessionManager = ref.read(chatSessionManagerProvider);
    if (text.isEmpty || sessionManager.isGenerating) return;

    _controller.clear();
    _focusNode.unfocus();
    setState(() => _showQuickPhrases = false);

    await sessionManager.sendMessage(text);
  }

  Future<void> _sendQuickPhrase(String text) async {
    final sessionManager = ref.read(chatSessionManagerProvider);
    if (sessionManager.isGenerating) return;

    _focusNode.unfocus();
    setState(() => _showQuickPhrases = false);

    await sessionManager.sendMessage(text);
  }

  void _toggleQuickPhrases() {
    _focusNode.unfocus();
    setState(() => _showQuickPhrases = !_showQuickPhrases);
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _closeDrawer() {
    _scaffoldKey.currentState?.closeDrawer();
  }

  @override
  Widget build(BuildContext context) {
    // 使用细粒度 Provider，只在真正关心的数据变化时重建
    final title = ref.watch(currentSessionTitleProvider);
    final hasMessages = ref.watch(hasMessagesProvider);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: _openDrawer,
          tooltip: '历史对话',
        ),
        title: Text(title),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (hasMessages)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                ref.read(chatSessionManagerProvider).clearCurrentSession();
              },
              tooltip: '清空当前对话',
            ),
        ],
      ),
      drawer: ChatDrawer(
        onClose: _closeDrawer,
      ),
      body: Column(
        children: [
          const Expanded(
            // const 确保 ChatPage 重建时 _MessageList 不跟着重建
            child: _MessageList(),
          ),
          if (_showQuickPhrases) _buildQuickPhrasePanel(),
          ChatInputBar(
            controller: _controller,
            focusNode: _focusNode,
            // 只监听 isGenerating，bool 的 == 比较可靠，
            // token 流式输出期间值不变，ChatInputBar 不重建
            isGenerating: ref.watch(isGeneratingProvider),
            onSend: _sendMessage,
            onQuickPhrase: _toggleQuickPhrases,
            onStop: () => ref.read(chatSessionManagerProvider).stopGeneration(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPhrasePanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: SafeArea(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickPhrases.map((text) {
            return ActionChip(
              label: Text(text),
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.grey.shade300),
              onPressed: () => _sendQuickPhrase(text),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// 消息列表组件 - 独立管理消息列表的渲染和自动滚动
///
/// 使用 [ConsumerStatefulWidget] + [currentMessagesProvider]，
/// 重建范围仅限于本组件子树。逐 token 更新时只重建列表区域，
/// 不会触发 [ChatPage] 级别的重建。
class _MessageList extends ConsumerStatefulWidget {
  const _MessageList();

  @override
  ConsumerState<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<_MessageList> {
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _lastMessageCount = ref.read(currentMessagesProvider).length;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(currentMessagesProvider);

    // 检测是否有新消息加入（非内容变化），决定是否自动滚动
    final currentCount = messages.length;
    final hasNewMessage = currentCount > _lastMessageCount;
    _lastMessageCount = currentCount;

    if (hasNewMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    if (messages.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        return _buildMessageItem(msg);
      },
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '开始对话吧',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '模型完全在本地运行，数据不会上传',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage msg) {
    final isUser = msg.role == MessageRole.user;

    return RepaintBoundary(
      child: isUser
          ? UserMessageBubble(key: ValueKey(msg.id), message: msg)
          : AssistantMessageBubble(key: ValueKey(msg.id), message: msg),
    );
  }
}
