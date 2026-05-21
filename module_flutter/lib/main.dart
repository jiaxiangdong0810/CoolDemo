import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'native/event_channel.dart';
import 'native/user_channel.dart';
import 'native/generated/api.g.dart';
import 'pages/about_page.dart';
import 'pages/agreement_detail_page.dart';
import 'pages/agreement_page.dart';
import 'pages/chat_page.dart';
import 'pages/model_setup_page.dart';
import 'pages/settings_page.dart';
import 'providers/chat_providers.dart';
import 'services/chat_session_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  EventApi.setUp(EventReceiver());
  runApp(
    ProviderScope(
      child: MyApp(initialRoute: PlatformDispatcher.instance.defaultRouteName),
    ),
  );
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
              builder: (_) => const ModelSetupPage(),
            );
          case '/chat':
            final args = settings.arguments as Map<String, dynamic>?;
            final sessionManager = args?['sessionManager'] as ChatSessionManager?;

            Widget chatPage = const ChatPage();
            if (sessionManager != null) {
              chatPage = ProviderScope(
                overrides: [
                  chatSessionManagerProvider.overrideWith((ref) => sessionManager),
                ],
                child: chatPage,
              );
            }
            return MaterialPageRoute(builder: (_) => chatPage);
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

class FirstFlutterPage extends StatefulWidget {
  const FirstFlutterPage({super.key});

  @override
  State<FirstFlutterPage> createState() => _FirstFlutterPageState();
}

class _FirstFlutterPageState extends State<FirstFlutterPage> {
  final _userChannel = UserChannel();
  final _eventReceiver = EventReceiver();

  UserInfo? _userInfo;
  bool _loadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _listenEvents();
  }

  void _listenEvents() {
    _eventReceiver.userInfoStream.listen((userInfo) {
      if (!mounted) return;
      setState(() {
        _userInfo = userInfo;
      });
    });
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = await _userChannel.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _userInfo = user;
        _loadingUser = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingUser = false;
      });
    }
  }

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 24),

              // 用户信息卡片（演示原生同步）
              _buildUserCard(),
              const SizedBox(height: 24),

              // AI 聊天入口
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ModelSetupPage(),
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
      ),
    );
  }

  Widget _buildUserCard() {
    if (_loadingUser) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final user = _userInfo;
    if (user == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.person_outline, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('未登录', style: TextStyle(color: Colors.grey)),
                    Text(
                      '原生修改用户信息后，进入此页面可同步显示',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text(
                (user.nickname ?? 'U').substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.nickname ?? '用户',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'ID: ${user.userId}${user.vipLevel != null && user.vipLevel! > 0 ? '  |  VIP ${user.vipLevel}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.sync, color: Colors.green, size: 16),
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
