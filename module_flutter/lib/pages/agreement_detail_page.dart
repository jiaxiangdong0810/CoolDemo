import 'package:flutter/material.dart';

/// 协议详情页面 - 协议模块的子页面
class AgreementDetailPage extends StatelessWidget {
  final Map<String, Object?> routeParams;

  const AgreementDetailPage({super.key, this.routeParams = const {}});

  @override
  Widget build(BuildContext context) {
    final title = routeParams['title'] as String? ?? '协议详情';
    final agreementId = routeParams['agreementId'] as String? ?? 'default';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.article_outlined, size: 80, color: Colors.teal),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'agreementId: $agreementId',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '这是一个伪协议详情页面，用于演示原生 → Flutter → Flutter 的导航流程。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('返回协议页面'),
            ),
          ],
        ),
      ),
    );
  }
}
