import 'dart:async';
import 'dart:convert';

import 'generated/api.g.dart';

class UserChannel {
  static final UserChannel _instance = UserChannel._internal();
  factory UserChannel() => _instance;
  UserChannel._internal();

  final _api = UserApi();

  final _userController = StreamController<UserInfo?>.broadcast();
  Stream<UserInfo?> get onUserChanged => _userController.stream;

  Future<UserInfo?> getCurrentUser() async {
    final resp = await _api.getCurrentUser();
    if (!resp.success) {
      throw NativeException(resp.errorCode, resp.errorMessage);
    }
    if (resp.data == null || resp.data!.isEmpty) return null;
    return _decodeUserInfo(resp.data!);
  }

  Future<bool> isLoggedIn() async {
    final resp = await _api.isLoggedIn();
    return resp.success && resp.data == 'true';
  }

  Future<void> updateUserInfo(UserInfo userInfo) async {
    final resp = await _api.updateUserInfo(userInfo);
    if (!resp.success) {
      throw NativeException(resp.errorCode, resp.errorMessage);
    }
  }

  Future<void> logout() async {
    final resp = await _api.logout();
    if (!resp.success) {
      throw NativeException(resp.errorCode, resp.errorMessage);
    }
  }

  void notifyUserChanged(UserInfo? userInfo) {
    _userController.add(userInfo);
  }

  UserInfo? _decodeUserInfo(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return UserInfo(
      userId: map['userId'] as String,
      nickname: map['nickname'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      vipLevel: map['vipLevel'] as int?,
    );
  }
}

class NativeException implements Exception {
  final String? code;
  final String? message;
  NativeException(this.code, this.message);

  @override
  String toString() => 'NativeException(code: $code, message: $message)';
}
