import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../widgets/assistant_message_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/user_message_bubble.dart';

/// 聊天主页面
class ChatPage extends StatefulWidget {
  final ChatService chatService;

  const ChatPage({super.key, required this.chatService});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  int _lastMessageCount = 0;
  bool _showQuickPhrases = false;

  // 常用语列表，自行修改内容
  final List<String> _quickPhrases = [
    '你好',
    '写一个java中的最优的单例子模式 使用markdown格式',
    '再见',
  ];

  @override
  void initState() {
    super.initState();
    widget.chatService.addListener(_onServiceChanged);
    _lastMessageCount = widget.chatService.messages.length;
  }

  @override
  void dispose() {
    widget.chatService.removeListener(_onServiceChanged);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;

    final currentCount = widget.chatService.messages.length;
    final hasNewMessage = currentCount > _lastMessageCount;
    _lastMessageCount = currentCount;

    setState(() {});

    // 只在新增消息时自动滚动，流式追加 token 时不滚动
    if (hasNewMessage) {
      _scrollToBottom();
    }
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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.chatService.isGenerating) return;

    _controller.clear();
    _focusNode.unfocus();
    setState(() => _showQuickPhrases = false);

    await widget.chatService.sendMessage(text);
  }

  Future<void> _sendQuickPhrase(String text) async {
    if (widget.chatService.isGenerating) return;

    _focusNode.unfocus();
    setState(() => _showQuickPhrases = false);

    await widget.chatService.sendMessage(text);
  }

  void _toggleQuickPhrases() {
    _focusNode.unfocus();
    setState(() => _showQuickPhrases = !_showQuickPhrases);
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.chatService.messages;
    final isGenerating = widget.chatService.isGenerating;

    return Scaffold(
      appBar: AppBar(
        title: const Text('本地 AI 助手'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              widget.chatService.clearHistory();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return _buildMessageItem(msg);
                    },
                  ),
          ),
          if (_showQuickPhrases) _buildQuickPhrasePanel(),
          ChatInputBar(
            controller: _controller,
            focusNode: _focusNode,
            isGenerating: isGenerating,
            onSend: _sendMessage,
            onQuickPhrase: _toggleQuickPhrases,
            onStop: widget.chatService.stopGeneration,
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
