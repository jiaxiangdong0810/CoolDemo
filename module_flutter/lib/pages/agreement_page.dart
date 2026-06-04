import 'package:flutter/material.dart';

import '../hybrid/hybrid_route.dart';

/// 协议页面 - 模块入口
class AgreementPage extends StatelessWidget {
  final Map<String, Object?> routeParams;

  const AgreementPage({super.key, this.routeParams = const {}});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户协议'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.description, size: 80, color: Colors.teal),
            const SizedBox(height: 20),
            const Text(
              '用户协议',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '原生 → Flutter(协议) → Flutter(协议详情)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed(
                  HybridRoute.flutter(
                    '/agreement_detail',
                    params: {
                      'agreementId': 'user_terms',
                      'title': '用户协议详情',
                      'source': 'agreement_page',
                      'parentFlowId': routeParams['flowId'],
                    },
                  ).toJson(),
                );
              },
              icon: const Icon(Icons.article),
              label: const Text('查看协议详情'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('返回原生'),
              style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}
