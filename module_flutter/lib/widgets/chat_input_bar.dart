import 'package:flutter/material.dart';

/// 底部聊天输入栏
class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isGenerating;
  final VoidCallback onSend;
  final VoidCallback? onQuickPhrase;
  final VoidCallback? onStop;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isGenerating,
    required this.onSend,
    this.onQuickPhrase,
    this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: !isGenerating,
                maxLines: null,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: isGenerating ? '模型正在思考...' : '输入消息...',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (!isGenerating && onQuickPhrase != null)
              IconButton(
                onPressed: onQuickPhrase,
                icon: const Icon(Icons.auto_fix_high),
                color: Colors.orange,
                iconSize: 24,
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: isGenerating
                  ? IconButton(
                      onPressed: onStop,
                      icon: const Icon(Icons.stop),
                      color: Colors.red,
                      iconSize: 24,
                    )
                  : IconButton(
                      onPressed: onSend,
                      icon: const Icon(Icons.send),
                      color: Colors.blue,
                      iconSize: 24,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
