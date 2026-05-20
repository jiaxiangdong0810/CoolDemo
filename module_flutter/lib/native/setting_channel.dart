import 'dart:async';
import 'dart:convert';

import 'generated/api.g.dart';

class SettingChannel {
  static final SettingChannel _instance = SettingChannel._internal();
  factory SettingChannel() => _instance;
  SettingChannel._internal();

  final _api = SettingApi();

  final _settingController = StreamController<Map<String, String?>>.broadcast();
  Stream<Map<String, String?>> get onSettingChanged => _settingController.stream;

  Future<Map<String, String?>> getAllSettings() async {
    final resp = await _api.getAllSettings();
    if (!resp.success) {
      throw _exception(resp);
    }
    if (resp.data == null || resp.data!.isEmpty) return {};
    final map = jsonDecode(resp.data!) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v as String?));
  }

  Future<String?> getSetting(String key) async {
    final resp = await _api.getSetting(key);
    if (!resp.success) {
      throw _exception(resp);
    }
    return resp.data;
  }

  Future<void> updateSetting(String key, String? value) async {
    final resp = await _api.updateSetting(key, value);
    if (!resp.success) {
      throw _exception(resp);
    }
  }

  Future<DeviceInfo> getDeviceInfo() async {
    final resp = await _api.getDeviceInfo();
    if (!resp.success) {
      throw _exception(resp);
    }
    final map = jsonDecode(resp.data!) as Map<String, dynamic>;
    return DeviceInfo(
      platform: map['platform'] as String,
      osVersion: map['osVersion'] as String,
      deviceModel: map['deviceModel'] as String,
      appVersion: map['appVersion'] as String,
    );
  }

  void notifySettingChanged(String key, String? value) {
    _settingController.add({key: value});
  }

  Exception _exception(ApiResponse resp) {
    return Exception('${resp.errorCode}: ${resp.errorMessage}');
  }
}
