import 'dart:async';

import 'generated/api.g.dart';

/// 原生事件接收器，实现 Pigeon 生成的 EventApi 接口
class EventReceiver implements EventApi {
  static final EventReceiver _instance = EventReceiver._internal();
  factory EventReceiver() => _instance;
  EventReceiver._internal();

  final _userController = StreamController<UserInfo?>.broadcast();
  final _settingController = StreamController<SettingChange>.broadcast();
  final _lifecycleController = StreamController<String>.broadcast();

  Stream<UserInfo?> get userInfoStream => _userController.stream;
  Stream<SettingChange> get settingStream => _settingController.stream;
  Stream<String> get lifecycleStream => _lifecycleController.stream;

  @override
  void onUserInfoChanged(UserInfo? userInfo) {
    _userController.add(userInfo);
  }

  @override
  void onSettingChanged(String key, String? value) {
    _settingController.add(SettingChange(key, value));
  }

  @override
  void onAppLifecycleChanged(String state) {
    _lifecycleController.add(state);
  }

  void dispose() {
    _userController.close();
    _settingController.close();
    _lifecycleController.close();
  }
}

class SettingChange {
  final String key;
  final String? value;
  SettingChange(this.key, this.value);
}
