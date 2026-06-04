import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _navigationChannel = MethodChannel('com.example.cooldemo/navigation');

class NavigationTestPage extends StatelessWidget {
  final String title;
  final String chain;
  final NavigationTestAction action;

  const NavigationTestPage({
    super.key,
    required this.title,
    required this.chain,
    required this.action,
  });

  Future<void> _openNativePage() async {
    await _navigationChannel.invokeMethod('openNativeHopPage', {
      'title': '原生中转页',
      'chain': chain,
    });
  }

  void _goNextFlutter(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NavigationTestPage(
          title: '$title - Flutter 第 2 页',
          chain: chain,
          action: action == NavigationTestAction.flutterThenNative
              ? NavigationTestAction.native
              : NavigationTestAction.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.route, size: 72, color: Colors.indigo),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  chain,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 36),
                _buildPrimaryAction(context),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      SystemNavigator.pop();
                    }
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('返回上一页'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryAction(BuildContext context) {
    switch (action) {
      case NavigationTestAction.flutter:
        return ElevatedButton.icon(
          onPressed: () => _goNextFlutter(context),
          icon: const Icon(Icons.navigate_next),
          label: const Text('打开 Flutter 第 2 页'),
        );
      case NavigationTestAction.native:
        return ElevatedButton.icon(
          onPressed: _openNativePage,
          icon: const Icon(Icons.open_in_new),
          label: const Text('打开原生页面'),
        );
      case NavigationTestAction.flutterThenNative:
        return ElevatedButton.icon(
          onPressed: () => _goNextFlutter(context),
          icon: const Icon(Icons.navigate_next),
          label: const Text('打开 Flutter 第 2 页'),
        );
      case NavigationTestAction.none:
        return ElevatedButton.icon(
          onPressed: SystemNavigator.pop,
          icon: const Icon(Icons.close),
          label: const Text('关闭 Flutter 页面'),
        );
    }
  }
}

enum NavigationTestAction { none, flutter, native, flutterThenNative }
