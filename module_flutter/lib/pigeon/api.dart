import 'package:pigeon/pigeon.dart';

// ============ 公共数据模型 ============

class UserInfo {
  final String userId;
  final String? nickname;
  final String? avatarUrl;
  final String? email;
  final String? phone;
  final int? vipLevel;
}

class SettingItem {
  final String key;
  final String? value;
  final String? label;
  final String? type;
}

class DeviceInfo {
  final String platform;
  final String osVersion;
  final String deviceModel;
  final String appVersion;
}

class ApiResponse {
  final bool success;
  final String? data;
  final String? errorCode;
  final String? errorMessage;
}

// ============ HostApi: Dart → Native ============

@HostApi()
abstract class UserApi {
  @async
  ApiResponse getCurrentUser();

  @async
  ApiResponse isLoggedIn();

  @async
  ApiResponse updateUserInfo(UserInfo userInfo);

  @async
  ApiResponse logout();
}

@HostApi()
abstract class SettingApi {
  @async
  ApiResponse getAllSettings();

  @async
  ApiResponse getSetting(String key);

  @async
  ApiResponse updateSetting(String key, String? value);

  @async
  ApiResponse getDeviceInfo();
}

// ============ FlutterApi: Native → Dart ============

@FlutterApi()
abstract class EventApi {
  void onUserInfoChanged(UserInfo? userInfo);

  void onSettingChanged(String key, String? value);

  void onAppLifecycleChanged(String state);
}
