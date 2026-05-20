import 'package:flutter/material.dart';

import '../native/event_channel.dart';
import '../native/setting_channel.dart';
import '../native/user_channel.dart';
import '../native/generated/api.g.dart';

/// 设置页面 - 与原生双向同步
///
/// 需求：
/// 1. 页面加载时从原生获取最新设置数据展示
/// 2. 用户在 Flutter 侧修改设置后，通过 Pigeon 通知原生同步保存
/// 3. 监听原生侧设置变更事件，实时更新 UI
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _settingChannel = SettingChannel();
  final _eventReceiver = EventReceiver();

  bool _loading = true;
  String? _error;

  // 设置值
  bool _notificationEnabled = true;
  String _darkMode = 'system';
  String _language = 'zh';
  String _fontSize = 'medium';
  bool _autoPlay = false;

  // 设备信息
  DeviceInfo? _deviceInfo;

  // 用户信息
  UserInfo? _userInfo;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserInfo();
    _listenEvents();
  }

  void _listenEvents() {
    _eventReceiver.settingStream.listen((change) {
      if (!mounted) return;
      setState(() {
        _applySetting(change.key, change.value);
      });
    });
  }

  void _applySetting(String key, String? value) {
    switch (key) {
      case 'notification_enabled':
        _notificationEnabled = value == 'true';
      case 'dark_mode':
        _darkMode = value ?? 'system';
      case 'language':
        _language = value ?? 'zh';
      case 'font_size':
        _fontSize = value ?? 'medium';
      case 'auto_play':
        _autoPlay = value == 'true';
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _settingChannel.getAllSettings();
      final deviceInfo = await _settingChannel.getDeviceInfo();
      if (!mounted) return;
      setState(() {
        _notificationEnabled = settings['notification_enabled'] == 'true';
        _darkMode = settings['dark_mode'] ?? 'system';
        _language = settings['language'] ?? 'zh';
        _fontSize = settings['font_size'] ?? 'medium';
        _autoPlay = settings['auto_play'] == 'true';
        _deviceInfo = deviceInfo;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = await UserChannel().getCurrentUser();
      if (!mounted) return;
      setState(() {
        _userInfo = user;
      });
    } catch (e) {
      // 忽略
    }
  }

  Future<void> _updateSetting(String key, String value) async {
    try {
      await _settingChannel.updateSetting(key, value);
      _applySetting(key, value);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    }
  }

  Future<void> _updateUserInfo() async {
    final nicknameController = TextEditingController(text: _userInfo?.nickname ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: nicknameController,
          decoration: const InputDecoration(hintText: '请输入昵称'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nicknameController.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;

    try {
      final updated = UserInfo(
        userId: _userInfo?.userId ?? 'guest',
        nickname: result.isEmpty ? null : result,
        avatarUrl: _userInfo?.avatarUrl,
        email: _userInfo?.email,
        phone: _userInfo?.phone,
        vipLevel: _userInfo?.vipLevel,
      );
      await UserChannel().updateUserInfo(updated);
      setState(() {
        _userInfo = updated;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('加载失败: $_error'))
              : ListView(
                  children: [
                    // 用户信息区（演示用户信息同步）
                    _buildUserSection(),
                    const Divider(),

                    // 设备信息
                    if (_deviceInfo != null) _buildDeviceSection(),
                    const Divider(),

                    // 通知设置
                    SwitchListTile(
                      secondary: const Icon(Icons.notifications),
                      title: const Text('消息通知'),
                      subtitle: const Text('接收推送消息'),
                      value: _notificationEnabled,
                      onChanged: (value) {
                        setState(() => _notificationEnabled = value);
                        _updateSetting('notification_enabled', value.toString());
                      },
                    ),

                    // 深色模式
                    ListTile(
                      leading: const Icon(Icons.dark_mode),
                      title: const Text('深色模式'),
                      subtitle: Text(_darkModeLabel(_darkMode)),
                      trailing: DropdownButton<String>(
                        value: _darkMode,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'light', child: Text('浅色')),
                          DropdownMenuItem(value: 'dark', child: Text('深色')),
                          DropdownMenuItem(value: 'system', child: Text('跟随系统')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _darkMode = value);
                          _updateSetting('dark_mode', value);
                        },
                      ),
                    ),

                    // 语言
                    ListTile(
                      leading: const Icon(Icons.language),
                      title: const Text('语言'),
                      subtitle: Text(_languageLabel(_language)),
                      trailing: DropdownButton<String>(
                        value: _language,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'zh', child: Text('简体中文')),
                          DropdownMenuItem(value: 'en', child: Text('English')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _language = value);
                          _updateSetting('language', value);
                        },
                      ),
                    ),

                    // 字体大小
                    ListTile(
                      leading: const Icon(Icons.format_size),
                      title: const Text('字体大小'),
                      subtitle: Text(_fontSizeLabel(_fontSize)),
                      trailing: DropdownButton<String>(
                        value: _fontSize,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'small', child: Text('小')),
                          DropdownMenuItem(value: 'medium', child: Text('中')),
                          DropdownMenuItem(value: 'large', child: Text('大')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _fontSize = value);
                          _updateSetting('font_size', value);
                        },
                      ),
                    ),

                    // 自动播放
                    SwitchListTile(
                      secondary: const Icon(Icons.play_circle),
                      title: const Text('自动播放'),
                      subtitle: const Text('进入页面自动播放内容'),
                      value: _autoPlay,
                      onChanged: (value) {
                        setState(() => _autoPlay = value);
                        _updateSetting('auto_play', value.toString());
                      },
                    ),

                    const Divider(),

                    // 关于
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('关于'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).pushNamed('/about');
                      },
                    ),

                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Pigeon 通信框架演示',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  Widget _buildUserSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '用户信息',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.indigo,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.indigo,
            child: Text(
              (_userInfo?.nickname ?? 'U').substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text(_userInfo?.nickname ?? '未设置昵称'),
          subtitle: Text(_userInfo?.userId ?? 'guest'),
          trailing: TextButton(
            onPressed: _updateUserInfo,
            child: const Text('修改'),
          ),
        ),
        if (_userInfo?.email != null)
          ListTile(
            leading: const Icon(Icons.email),
            title: Text(_userInfo!.email!),
            dense: true,
          ),
        if (_userInfo?.phone != null)
          ListTile(
            leading: const Icon(Icons.phone),
            title: Text(_userInfo!.phone!),
            dense: true,
          ),
        if (_userInfo?.vipLevel != null && _userInfo!.vipLevel! > 0)
          ListTile(
            leading: const Icon(Icons.star, color: Colors.amber),
            title: Text('VIP ${_userInfo!.vipLevel}'),
            dense: true,
          ),
      ],
    );
  }

  Widget _buildDeviceSection() {
    final d = _deviceInfo!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '设备信息',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.indigo,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ListTile(
          dense: true,
          title: const Text('平台'),
          trailing: Text(d.platform),
        ),
        ListTile(
          dense: true,
          title: const Text('系统版本'),
          trailing: Text(d.osVersion),
        ),
        ListTile(
          dense: true,
          title: const Text('设备型号'),
          trailing: Text(d.deviceModel),
        ),
        ListTile(
          dense: true,
          title: const Text('App 版本'),
          trailing: Text(d.appVersion),
        ),
      ],
    );
  }

  String _darkModeLabel(String value) {
    switch (value) {
      case 'light':
        return '浅色';
      case 'dark':
        return '深色';
      default:
        return '跟随系统';
    }
  }

  String _languageLabel(String value) {
    switch (value) {
      case 'en':
        return 'English';
      default:
        return '简体中文';
    }
  }

  String _fontSizeLabel(String value) {
    switch (value) {
      case 'small':
        return '小';
      case 'large':
        return '大';
      default:
        return '中';
    }
  }
}
