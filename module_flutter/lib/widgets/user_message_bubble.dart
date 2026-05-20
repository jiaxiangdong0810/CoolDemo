import 'package:flutter/material.dart';
import '../services/chat_service.dart';

/// 用户发送的消息气泡
class UserMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const UserMessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: const Radius.circular(4),
          ),
        ),
        child: SelectableText(
          message.content,
          style: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }
}
