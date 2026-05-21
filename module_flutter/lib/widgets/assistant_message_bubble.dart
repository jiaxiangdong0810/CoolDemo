import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';

/// AI 返回的消息气泡
class AssistantMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const AssistantMessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: const Radius.circular(4),
          ),
        ),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (message.content.isEmpty && !message.isComplete) {
      return SizedBox(
        width: 40,
        height: 20,
        child: LinearProgressIndicator(
          backgroundColor: Colors.grey.shade300,
          valueColor: AlwaysStoppedAnimation(Colors.blue.shade400),
        ),
      );
    }

    // 流式输出阶段用纯 Text 渲染，避免 MarkdownBody 每个 token 都重新解析
    // 完成后切换为 MarkdownBody 渲染富文本
    if (!message.isComplete) {
      return Text(
        message.content,
        style: const TextStyle(fontSize: 15),
      );
    }

    return MarkdownBody(
      data: message.content,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(fontSize: 15, color: Colors.black87),
        h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
        h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        em: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87),
        code: TextStyle(
          fontSize: 13,
          backgroundColor: Colors.grey.shade300,
          color: Colors.black87,
          fontFamily: 'monospace',
        ),
        codeblockDecoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquote: TextStyle(
          fontSize: 15,
          color: Colors.grey.shade700,
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: Colors.grey.shade400, width: 4)),
          color: Colors.grey.shade50,
        ),
        blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        listBullet: const TextStyle(fontSize: 15, color: Colors.black87),
        a: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
      ),
    );
  }
}
