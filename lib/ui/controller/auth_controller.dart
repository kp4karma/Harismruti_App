import 'dart:convert';
import 'dart:math';

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/auth_repository.dart';
import 'package:harismruti/helper/navigation_helper.dart';
import 'package:harismruti/helper/top_notification_helper.dart';
import 'package:harismruti/ui/controller/ProfileController.dart';
import 'package:harismruti/utils/app_routes.dart';
import 'package:harismruti/utils/storage_helper.dart';

class AuthController extends GetxController {
  AuthController({AuthRepository? repository})
    : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;

  final RxBool isLoading = false.obs;
  final RxString lastMobile = ''.obs;
  final RxString lastEmail = ''.obs;
  final RxString lastValidationMethod = 'email'.obs;

  Future<bool> login({
    required String mobile,
    required String validationMethod,
  }) async {
    final formattedMobile = _formatMobile(mobile);
    if (formattedMobile.isEmpty) {
      TopNotification.error('Please enter mobile number');
      return false;
    }

    return _runAuthRequest(() async {
      final response = await _repository.login(
        mobile: formattedMobile,
        validationMethod: validationMethod,
      );
      if (!_isSuccessfulResponse(response.data)) {
        _showServerError(response.data, fallback: 'Login failed');
        return false;
      }
      lastMobile.value = formattedMobile;
      lastEmail.value = _extractEmail(response.data);
      lastValidationMethod.value = validationMethod;
      _showServerMessage(response.data, fallback: 'OTP sent successfully');
      return true;
    });
  }

  Future<bool> register({
    required String fullName,
    required String mobile,
    required String city,
    required String validationMethod,
    required String email,
  }) async {
    final formattedMobile = _formatMobile(mobile);
    if (fullName.trim().isEmpty ||
        formattedMobile.isEmpty ||
        email.trim().isEmpty) {
      TopNotification.error('Please fill all required fields');
      return false;
    }
    if (!_isValidEmail(email)) {
      TopNotification.error('Please enter valid email');
      return false;
    }

    return _runAuthRequest(() async {
      final response = await _repository.register(
        fullName: fullName.trim(),
        mobile: formattedMobile,
        city: city.trim(),
        validationMethod: validationMethod,
        email: email.trim(),
      );
      if (!_isSuccessfulResponse(response.data)) {
        _showServerError(response.data, fallback: 'Registration failed');
        return false;
      }
      lastMobile.value = formattedMobile;
      lastValidationMethod.value = validationMethod;
      _showServerMessage(
        response.data,
        fallback: 'User registered successfully',
      );
      return true;
    });
  }

  Future<bool> verifyOtp({required String otp}) async {
    if (lastMobile.value.isEmpty) {
      TopNotification.error('Mobile number missing. Please login again.');
      return false;
    }
    if (otp.trim().length != 6) {
      TopNotification.error('Please enter valid OTP');
      return false;
    }

    return _runAuthRequest(() async {
      final response = await _repository.verifyOtp(
        username: lastMobile.value,
        otp: otp.trim(),
        deviceId: _deviceId(),
      );
      if (!_isSuccessfulResponse(response.data)) {
        _showServerError(response.data, fallback: 'OTP verification failed');
        return false;
      }
      _persistLogin(response.data);
      NavigationHelper.navigateAndRemoveAll(AppRoutes.home);
      return true;
    });
  }

  Future<bool> resendOtp() {
    return login(
      mobile: lastMobile.value,
      validationMethod: lastValidationMethod.value,
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    ).hasMatch(email.trim());
  }

  Future<bool> _runAuthRequest(Future<bool> Function() request) async {
    if (isLoading.value) return false;

    try {
      isLoading.value = true;
      EasyLoading.show();
      return await request();
    } catch (error) {
      TopNotification.error(_cleanError(error));
      return false;
    } finally {
      isLoading.value = false;
      await EasyLoading.dismiss();
    }
  }

  void _persistLogin(dynamic responseData) {
    final data = responseData is Map ? responseData['data'] : null;
    if (data is! Map) return;

    final token = data['token']?.toString() ?? '';
    if (token.isNotEmpty) {
      StorageHelper.setValue(key: StorageKeys.accessToken, value: token);
      StorageHelper.setValue(key: StorageKeys.refreshToken, value: token);
    }

    StorageHelper.setValue(
      key: StorageKeys.tokenExpiresAt,
      value: data['token_expires_at']?.toString() ?? '',
    );
    StorageHelper.setValue(
      key: StorageKeys.currentDeviceId,
      value: data['current_device_id']?.toString() ?? '',
    );
    if (data['profile'] != null) {
      StorageHelper.setValue(
        key: StorageKeys.userProfile,
        value: jsonEncode(data['profile']),
      );
      if (Get.isRegistered<ProfileController>()) {
        Get.find<ProfileController>().loadStoredProfile();
      }
    }
  }

  void _showServerMessage(dynamic responseData, {required String fallback}) {
    TopNotification.success(_serverMessage(responseData, fallback: fallback));
  }

  void _showServerError(dynamic responseData, {required String fallback}) {
    TopNotification.error(_serverMessage(responseData, fallback: fallback));
  }

  bool _isSuccessfulResponse(dynamic responseData) {
    return responseData is Map && responseData['success'] == true;
  }

  String _extractEmail(dynamic responseData) {
    final message = responseData is Map ? responseData['message'] : null;
    if (message is Map && message['email'] != null) {
      return message['email'].toString().trim();
    }
    return '';
  }

  String _serverMessage(dynamic responseData, {required String fallback}) {
    final message = responseData is Map ? responseData['message'] : null;
    if (message is Map && message['message'] != null) {
      return message['message'].toString();
    }
    if (message is String && message.isNotEmpty) {
      return message;
    }
    return fallback;
  }

  String _formatMobile(String value) {
    final trimmed = value.trim().replaceAll(' ', '');
    if (trimmed.isEmpty) return '';
    return trimmed.startsWith('+') ? trimmed : '+91$trimmed';
  }

  String _deviceId() {
    final existing = StorageHelper.getValue<String>(key: StorageKeys.deviceId);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(8, (_) => random.nextInt(256));
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final deviceId = '${hex}_harismruti';
    StorageHelper.setValue(key: StorageKeys.deviceId, value: deviceId);
    return deviceId;
  }

  String _cleanError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    return raw.isEmpty ? 'Something went wrong' : raw;
  }
}
