import 'package:dio/dio.dart';
import 'package:harismruti/api/api_client.dart';
import 'package:harismruti/api/api_endpoints.dart';

class AuthRepository {
  Future<Response<dynamic>> login({
    required String mobile,
    required String validationMethod,
  }) {
    return ApiClient.post(
      ApiEndpoints.login,
      data: {'mobile': mobile, 'validation_method': validationMethod},
    );
  }

  Future<Response<dynamic>> verifyOtp({
    required String username,
    required String otp,
    required String deviceId,
  }) {
    return ApiClient.post(
      ApiEndpoints.verifyOtp,
      data: {'username': username, 'otp': otp, 'device_id': deviceId},
    );
  }

  Future<Response<dynamic>> verifyToken() {
    return ApiClient.get(
      ApiEndpoints.verifyToken,
      forceRefresh: true,
      cacheDuration: Duration.zero,
    );
  }

  Future<Response<dynamic>> register({
    required String fullName,
    required String mobile,
    required String city,
    required String validationMethod,
    required String email,
  }) {
    return ApiClient.post(
      ApiEndpoints.register,
      data: {
        'full_name': fullName,
        'mobile': mobile,
        'city': city,
        'validation_method': validationMethod,
        'email': email,
      },
    );
  }
}
