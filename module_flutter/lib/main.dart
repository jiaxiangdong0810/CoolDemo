import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pages/about_page.dart';
import 'pages/agreement_detail_page.dart';
import 'pages/agreement_page.dart';
import 'pages/chat_page.dart';
import 'pages/model_setup_page.dart';
import 'pages/settings_page.dart';
import 'services/llama_service.dart';

void main() {
  runApp(MyApp(initialRoute: PlatformDispatcher.instance.defaultRouteName));
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // 关键：使用 initialRoute + onGenerateRoute，不再同时设置 home
      // 避免 Navigator 栈中重复压入同一页面（home + initialRoute 冲突）
      initialRoute: initialRoute,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => const FirstFlutterPage(),
            );
          case '/model_setup':
            return MaterialPageRoute(
              builder: (_) => ModelSetupPage(llamaService: LlamaService()),
            );
          case '/chat':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => ChatPage(
                chatService: args?['chatService'],
              ),
            );
          case '/second':
            return MaterialPageRoute(
              builder: (_) => const SecondFlutterPage(),
            );
          case '/settings':
            return MaterialPageRoute(
              builder: (_) => const SettingsPage(),
            );
          case '/about':
            return MaterialPageRoute(
              builder: (_) => const AboutPage(),
            );
          case '/agreement':
            return MaterialPageRoute(
              builder: (_) => const AgreementPage(),
            );
          case '/agreement_detail':
            return MaterialPageRoute(
              builder: (_) => const AgreementDetailPage(),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const FirstFlutterPage(),
            );
        }
      },
    );
  }
}

/// MethodChannel 用于与原生通信
const _channel = MethodChannel('com.example.cooldemo/navigation');

class FirstFlutterPage extends StatelessWidget {
  const FirstFlutterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter 第一个页面'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flutter_dash, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              'Flutter 第 1 页',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '原生 → Flutter(第1页) → Flutter(第2页) → 原生',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            // AI 聊天入口
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ModelSetupPage(
                      llamaService: LlamaService(),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble),
              label: const Text('本地 AI 聊天'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SecondFlutterPage(),
                  ),
                );
              },
              icon: const Icon(Icons.navigate_next),
              label: const Text('打开第二个 Flutter 页面'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                SystemNavigator.pop();
              },
              icon: const Icon(Icons.close),
              label: const Text('关闭页面（返回原生）'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SecondFlutterPage extends StatelessWidget {
  const SecondFlutterPage({super.key});

  Future<void> _openNativePage() async {
    try {
      await _channel.invokeMethod('openNativeSecondPage');
    } catch (e) {
      debugPrint('打开原生页面失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter 第二个页面'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.flutter_dash, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              'Flutter 第 2 页',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '当前仍在同一个 FlutterEngine 中',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _openNativePage,
              icon: const Icon(Icons.open_in_new),
              label: const Text('打开 Android 原生第二个页面'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('返回上一个 Flutter 页面'),
            ),
          ],
        ),
      ),
    );
  }
}
