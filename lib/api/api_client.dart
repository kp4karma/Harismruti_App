import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' as get_x;

import 'package:harismruti/api/api_endpoints.dart';
import 'package:harismruti/helper/log_helper.dart';
import 'package:harismruti/helper/top_notification_helper.dart';
import 'package:harismruti/utils/app_routes.dart';
import 'package:harismruti/utils/storage_helper.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ApiClient {
  static Dio? _client;
  static final ApiClient _instance = ApiClient._internal();
  static final Map<String, _CachedGetResponse> _getCache = {};
  static final Map<String, Future<Response<dynamic>>> _pendingGets = {};
  static const Duration _defaultGetCacheDuration = Duration(minutes: 15);
  factory ApiClient() => _instance;
  static String currentAppVersion = '';
  ApiClient._internal();

  static List<String> skipAuthEndpoints = [
    ApiEndpoints.login,
    ApiEndpoints.verifyOtp,
    ApiEndpoints.register,
  ];

  static Future<void> init() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    currentAppVersion = _isAndroid ? "1" : packageInfo.buildNumber;
    if (_client == null) {
      _client = Dio(
        BaseOptions(
          baseUrl: ApiEndpoints.mainDomain,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 60),
          headers: {'Content-Type': 'application/json'},
        ),
      );

      _client!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            String? token = await _getAccessToken();

            bool shouldSkipAuth = skipAuthEndpoints.any(
              (endpoint) =>
                  options.path.endsWith(endpoint) ||
                  options.uri.path.endsWith(endpoint),
            );
            if (kDebugMode) {
              print("$shouldSkipAuth API CLIENT TOKEN :: $token");
            }

            final osType = _osType;
            if (ApiEndpoints.mobileApiKey.isNotEmpty) {
              options.headers['X-API-Key'] = ApiEndpoints.mobileApiKey;
            }

            if (!shouldSkipAuth && token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            final mobileUserKey = _mobileUserKey();
            if (mobileUserKey.isNotEmpty) {
              options.headers['X-Mobile-User-Key'] = mobileUserKey;
            }

            if (options.data != null && options.data is! FormData) {
              if (options.data is Map || options.data is List) {
                options.extra['_originalData'] = options.data;
                if (['POST', 'PUT', 'DELETE'].contains(options.method)) {
                  options.data = jsonEncode(options.data);
                }
              }
            }
            if (options.data is FormData) {
              options.headers['Content-Type'] = 'multipart/form-data';
            }

            if (!options.path.contains('http')) {
              options.path = ApiEndpoints.mainDomain + options.path;
            }
            options.headers['X-App-Version'] = "$currentAppVersion-$osType";

            if (kDebugMode) {
              log('📤 REQUEST');
              log('➡️ [${options.method}] ${options.uri}');
              log('🔘 Headers: ${options.headers}');
              log('📝 Data: ${options.data}');
            }

            return handler.next(options);
          },
          onResponse: (response, handler) {
            if (kDebugMode) {
              final responseText = response.toString();
              log(
                responseText.length > 1200
                    ? '${responseText.substring(0, 1200)}...'
                    : responseText,
              );
            }
            if (response.statusCode == 200 || response.statusCode == 201) {
              return handler.next(response);
            }
            return handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
              ),
            );
          },
          onError: (DioException error, handler) async {
            if (kDebugMode) {
              print("🔗 Request URL: ${error.requestOptions.uri}");
              print("🟡 Request Method: ${error.requestOptions.method}");
              print("🟡 Request Method: ${error.requestOptions.method}");
            }

            String url = error.requestOptions.uri.toString();
            String method = error.requestOptions.method;
            int? statusCode = error.response?.statusCode;
            String responseData =
                error.response?.data.toString() ?? 'No response data';

            // Create a structured log
            String log =
                '''
🔻 ERROR LOG 🔻
URL: $url
METHOD: $method
STATUS: $statusCode
DATA: $responseData
''';

            await SecureLogger.write(log);

            if (error.response != null) {
              switch (statusCode) {
                case 400:
                  if (kDebugMode) {
                    print("400 Bad Request Error: $responseData");
                  }
                  break;
                case 401:
                  if (kDebugMode) {
                    print("401 Invalid Token Error: $responseData");
                  }
                  break;
                case 403:
                  if (await _shouldRetry(error)) {
                    return handler.resolve(await _retry(error.requestOptions));
                  }
                  break;
                case 404:
                  if (kDebugMode) {
                    print("404 API Error: $responseData");
                  }
                  break;
                case 440:
                  if (kDebugMode) {
                    print("440 Forced Login Error: $responseData");
                  }
                  break;
                case 500:
                  if (kDebugMode) {
                    print("500 Server Error: Internal Server Error");
                  }
                  break;
                default:
                  if (kDebugMode) {
                    print("Unhandled Error: $statusCode");
                  }
              }
            }

            return handler.next(error);
          },
        ),
      );
    }
  }

  static Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    String? newAccessToken = await _refreshToken();
    if (newAccessToken != null) {
      requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      return _client!.fetch<dynamic>(requestOptions);
    } else {
      return Response(
        requestOptions: requestOptions,
        statusCode: 440, // Unauthorized
        data: {"error": "Refresh token expired. Please re-login."},
      );
    }
  }

  static Future<String?> _refreshToken() async {
    String? refreshToken = StorageHelper.getValue(
      key: StorageKeys.refreshToken,
    );
    if (refreshToken == null || refreshToken.isEmpty) {
      _forceLogout();
      return null;
    }

    try {
      final response = await _client!.post(
        ApiEndpoints.refresh,
        options: Options(headers: {'Content-Type': 'application/json'}),
        data: addExtraParameters({}),
      );

      if (response.statusCode == 200) {
        final data = response.data is Map ? response.data['data'] : null;
        String newAccessToken = data is Map
            ? data['token']?.toString() ?? ''
            : '';
        String newRefreshToken = newAccessToken;

        if (newAccessToken.isEmpty) {
          _forceLogout();
          return null;
        }

        StorageHelper.setValue(
          key: StorageKeys.accessToken,
          value: newAccessToken,
        );
        StorageHelper.setValue(
          key: StorageKeys.refreshToken,
          value: newRefreshToken,
        );
        StorageHelper.setValue(
          key: StorageKeys.tokenExpiresAt,
          value: data is Map ? data['token_expires_at']?.toString() ?? '' : '',
        );
        StorageHelper.setValue(
          key: StorageKeys.currentDeviceId,
          value: data is Map ? data['current_device_id']?.toString() ?? '' : '',
        );

        if (kDebugMode) {
          print("✅ Token refreshed successfully!");
        }
        return newAccessToken;
      } else if (response.statusCode == 401) {
        if (kDebugMode) {
          print("🔴 Refresh token expired. Logging out...");
        }
        _forceLogout(); // Call logout function
      }
    } catch (e) {
      if (kDebugMode) {
        print("🔴 Token refresh failed: $e");
      }
      _forceLogout();
    }

    return null;
  }

  static void _forceLogout() {
    if (kDebugMode) {
      print("🔴 Logging out user...");
    }

    StorageHelper.setValue(key: StorageKeys.accessToken, value: "");
    StorageHelper.setValue(key: StorageKeys.refreshToken, value: "");
    get_x.Get.offAllNamed(AppRoutes.home);
  }

  static Future<String?> _getAccessToken() async {
    return StorageHelper.getValue(key: StorageKeys.accessToken);
  }

  static String _mobileUserKey() {
    final profileJson = StorageHelper.getValue<String>(
      key: StorageKeys.userProfile,
    );
    if (profileJson == null || profileJson.isEmpty) return '';
    try {
      final decoded = jsonDecode(profileJson);
      if (decoded is Map) {
        for (final key in ['id', 'user_id', 'mobile', 'username', 'email']) {
          final value = decoded[key]?.toString().trim() ?? '';
          if (value.isNotEmpty && value != 'null') return value;
        }
      }
    } catch (_) {}
    return '';
  }

  static Future<bool> _shouldRetry(DioException error) async {
    if (error.response?.data['detail'].toString() ==
        "Authentication error: Invalid or expired token.") {
      String? refreshToken = StorageHelper.getValue(
        key: StorageKeys.refreshToken,
      );
      if (refreshToken != null && refreshToken.isNotEmpty) {
        if (kDebugMode) {
          print("🔄 Should retry: 403 detected & refresh token is available.");
        }
        return true;
      } else {
        if (kDebugMode) {
          print("🔴 Should NOT retry: No valid refresh token found.");
        }
        return false;
      }
    } else if (error.response?.data['detail'].toString() ==
        "Authentication error: Please install latest app version") {
      TopNotification.error(
        error.response!.data['detail']
            .toString()
            .split(":")
            .last
            .trim()
            .toString(),
      );
    }
    return false;
  }

  static Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? customHeaders,
    Duration cacheDuration = _defaultGetCacheDuration,
    bool forceRefresh = false,
  }) async {
    final params = addExtraParameters(queryParams ?? {});
    final cacheKey = _getCacheKey(path, params);
    final cached = _getCache[cacheKey];
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.savedAt) < cacheDuration) {
      return cached.response;
    }

    if (!forceRefresh) {
      final pending = _pendingGets[cacheKey];
      if (pending != null) return pending;
    }

    final request = _performGetWithRetry(
      path,
      queryParams: params,
      customHeaders: customHeaders,
    );
    _pendingGets[cacheKey] = request;
    try {
      final response = await request;
      _getCache[cacheKey] = _CachedGetResponse(
        response: response,
        savedAt: DateTime.now(),
      );
      return response;
    } on DioException catch (e) {
      if (cached != null) return cached.response;
      if (kDebugMode) {
        print("Messsssss ${e.error}");
        print("Messsssss ${e.response}");
      }

      throw _handleError(e);
    } finally {
      _pendingGets.remove(cacheKey);
    }
  }

  static Future<Response<dynamic>> _performGet(
    String path, {
    required Map<String, dynamic> queryParams,
    Map<String, dynamic>? customHeaders,
  }) {
    return _client!.get(
      path,
      queryParameters: queryParams,
      options: Options(headers: customHeaders),
    );
  }

  static Future<Response<dynamic>> _performGetWithRetry(
    String path, {
    required Map<String, dynamic> queryParams,
    Map<String, dynamic>? customHeaders,
  }) async {
    try {
      return await _performGet(
        path,
        queryParams: queryParams,
        customHeaders: customHeaders,
      );
    } on DioException catch (error) {
      final shouldRetry =
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError ||
          const {502, 503, 504}.contains(error.response?.statusCode);
      if (!shouldRetry) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 700));
      return _performGet(
        path,
        queryParams: queryParams,
        customHeaders: customHeaders,
      );
    }
  }

  static String _getCacheKey(String path, Map<String, dynamic> queryParams) {
    final keys = queryParams.keys.toList()..sort();
    final query = keys
        .map((key) => '$key=${jsonEncode(queryParams[key])}')
        .join('&');
    return '${_mobileUserKey()}|$path|$query';
  }

  static void clearGetCache() {
    _getCache.clear();
    _pendingGets.clear();
  }

  static Future<Response<dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? customHeaders,
  }) async {
    try {
      clearGetCache();
      Response response = await _client!.post(
        path,
        data: addExtraParameters(data ?? {}),
        queryParameters: queryParams,
      );
      return response;
    } on DioException catch (e) {
      if (kDebugMode) {
        print(e);
      }
      throw _handleError(e);
    }
  }

  static Future<Response<dynamic>> postMedia(
    String path, {
    required FormData data,
  }) async {
    try {
      clearGetCache();
      final processedData = addExtraParametersFromData(data);
      Response response = await _client!.post(
        path,
        data: processedData,
        options: Options(contentType: "multipart/form-data"),
      );
      return response;
    } on DioException catch (e) {
      if (kDebugMode) {
        print(e);
      }
      throw _handleError(e);
    }
  }

  static Future<Response<dynamic>> put(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? customHeaders,
  }) async {
    try {
      clearGetCache();
      if (kDebugMode) {
        print(addExtraParameters(data ?? {}));
      }
      Response response = await _client!.put(
        path,
        data: addExtraParameters(data ?? {}),
        queryParameters: queryParams,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  static Future<Response<dynamic>> delete(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? customHeaders,
  }) async {
    try {
      clearGetCache();
      Response response = await _client!.delete(
        path,
        data: addExtraParameters(data ?? {}),
        queryParameters: queryParams,
        options: Options(headers: customHeaders),
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  static Exception _handleError(DioException error) {
    if (error.response != null) {
      final statusCode = error.response?.statusCode;
      final errorData = error.response?.data;
      final message = _extractErrorMessage(errorData);

      final logMessage =
          'Status: $statusCode, Message: $message, Response: $errorData';

      if (kDebugMode) {
        print("Logsssss $logMessage");
      }
      SecureLogger.write(logMessage); // Save to file

      switch (statusCode) {
        case 400:
        case 401:
        case 403:
        case 404:
        case 440:
        case 500:
          if (kDebugMode) {
            print("🛑 Error $statusCode: $message");
          }
          return Exception(message);
        default:
          return Exception("⚠️ Error: $errorData");
      }
    }

    SecureLogger.write("Unknown Dio Error: ${error.message}");
    return Exception("⚠️ Unknown Error: ${error.message}");
  }

  static String _extractErrorMessage(dynamic errorData) {
    if (errorData is Map) {
      final detail = errorData['detail'];
      if (detail is Map) {
        final nestedMessage = detail['message'];
        if (nestedMessage is String && nestedMessage.isNotEmpty) {
          return nestedMessage;
        }
        if (nestedMessage is Map && nestedMessage['message'] != null) {
          return nestedMessage['message'].toString();
        }
      }
      if (detail is String && detail.isNotEmpty) return detail;

      final message = errorData['message'];
      if (message is String && message.isNotEmpty) return message;
      if (message is Map && message['message'] != null) {
        return message['message'].toString();
      }
    }
    return errorData?.toString() ?? 'Unknown error message';
  }

  static dynamic addExtraParametersFromData(dynamic data) {
    if (data is FormData) {
      final extraFields = {};
      data.fields.addAll(
        extraFields.entries.map((e) => MapEntry(e.key, e.value.toString())),
      );
      return data;
    } else {
      return data;
    }
  }

  static dynamic addExtraParameters(Map<String, dynamic> data) {
    return {...data};
  }

  static bool handleValidationError(dynamic json) {
    if (json is Map && json.containsKey('message')) {
      final message = json['message'].toString();
      if (message.isNotEmpty) {
        TopNotification.error(message);
        return false; // error handled
      }
    }
    return true;
  }

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static String get _osType {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }
}

class _CachedGetResponse {
  final Response<dynamic> response;
  final DateTime savedAt;

  const _CachedGetResponse({required this.response, required this.savedAt});
}
