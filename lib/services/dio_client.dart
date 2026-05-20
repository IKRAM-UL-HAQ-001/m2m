import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

class TokenStorage {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKey);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshKey);
  }

  static Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, token);
  }

  static Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshKey, token);
  }
}

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;
  DioClient._internal();

  static final String baseUrl = AppConstants.serverBaseUrl;
  static final String wsUrl = AppConstants.wsBaseUrl;

  late Dio dio;
  late Dio uploadDio;

  bool _initialized = false;
  bool _isRefreshing = false;

  final _cacheOptions = CacheOptions(
    store: MemCacheStore(),
    policy: CachePolicy.refreshForceCache,
    hitCacheOnErrorExcept: [401, 403],
    maxStale: const Duration(minutes: 5),
    priority: CachePriority.normal,
  );

  void initialize() {
    if (_initialized) return;

    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    uploadDio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 5),
        sendTimeout: const Duration(minutes: 5),
        headers: const {'Accept': 'application/json'},
      ),
    );

    _addInterceptors();
    _initialized = true;
  }

  void _addInterceptors() {
    dio.interceptors.add(_authInterceptor(retry401: true));
    uploadDio.interceptors.add(_authInterceptor(retry401: true));

    dio.interceptors.add(DioCacheInterceptor(options: _cacheOptions));

    if (kDebugMode) {
      final logger = PrettyDioLogger(
        requestHeader: false,
        requestBody: false,
        responseBody: false,
        responseHeader: false,
        error: true,
        compact: true,
      );
      dio.interceptors.add(logger);
      uploadDio.interceptors.add(logger);
    }

    dio.interceptors.add(_retryInterceptor(dio));
    uploadDio.interceptors.add(_retryInterceptor(uploadDio));
  }

  InterceptorsWrapper _authInterceptor({required bool retry401}) {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenStorage.getAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (retry401 && error.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            final token = await TokenStorage.getAccessToken();
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            try {
              final client = error.requestOptions.extra['upload'] == true
                  ? uploadDio
                  : dio;
              final response = await client.fetch(error.requestOptions);
              handler.resolve(response);
              return;
            } catch (_) {}
          }
        }
        handler.next(error);
      },
    );
  }

  InterceptorsWrapper _retryInterceptor(Dio client) {
    return InterceptorsWrapper(
      onError: (error, handler) async {
        final retryCount =
            (error.requestOptions.extra['retryCount'] as int?) ?? 0;
        if (_shouldRetry(error) && retryCount < 2) {
          try {
            error.requestOptions.extra['retryCount'] = retryCount + 1;
            await Future.delayed(Duration(seconds: 1 << retryCount));
            final response = await client.fetch(error.requestOptions);
            handler.resolve(response);
            return;
          } catch (_) {}
        }
        handler.next(error);
      },
    );
  }

  bool _shouldRetry(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.response?.statusCode == 503;
  }

  Future<bool> _refreshToken() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;
    try {
      final refresh = await TokenStorage.getRefreshToken();
      if (refresh == null || refresh.isEmpty) return false;

      final response = await Dio().post(
        '${AppConstants.authBaseUrl}/token/refresh/',
        data: {'refresh': refresh},
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: const {'Content-Type': 'application/json'},
        ),
      );

      final data = Map<String, dynamic>.from(response.data as Map);
      final newAccess = data['access'] as String?;
      if (newAccess == null) return false;
      await TokenStorage.saveAccessToken(newAccess);
      final newRefresh = data['refresh'] as String?;
      if (newRefresh != null) {
        await TokenStorage.saveRefreshToken(newRefresh);
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  static String mediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) {
      return path;
    }
    final p = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$p';
  }
}
