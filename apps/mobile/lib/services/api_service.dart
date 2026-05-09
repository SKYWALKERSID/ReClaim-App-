import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  static Function? onUnauthorized;

  final Dio dio = Dio(BaseOptions(
    baseUrl: 'http://10.0.2.2:4000/v1',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  bool _isRefreshing = false;
  final List<void Function(String)> _pendingRequests = [];

  ApiService._internal() {
    _migrateFromSharedPrefs();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401 && e.requestOptions.path != '/auth/refresh') {
          if (_isRefreshing) {
            // Queue the request
            _pendingRequests.add((String newToken) async {
              e.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              handler.resolve(await dio.fetch(e.requestOptions));
            });
            return;
          }

          _isRefreshing = true;
          try {
            final refreshToken = await _storage.read(key: 'refresh_token');
            if (refreshToken == null) throw Exception('No refresh token');

            final response = await dio.post('/auth/refresh', data: {
              'refreshToken': refreshToken,
            });

            final newAccessToken = response.data['accessToken'];
            final newRefreshToken = response.data['refreshToken'];

            await saveTokens(newAccessToken, newRefreshToken);

            // Replay pending requests
            for (final callback in _pendingRequests) {
              callback(newAccessToken);
            }
            _pendingRequests.clear();

            // Replay original request
            e.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
            return handler.resolve(await dio.fetch(e.requestOptions));
          } catch (refreshError) {
            await clearTokens();
            onUnauthorized?.call();
            return handler.next(e);
          } finally {
            _isRefreshing = false;
          }
        }
        return handler.next(e);
      },
    ));
  }

  Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  Future<String?> getAccessToken() => _storage.read(key: 'access_token');
  Future<String?> getRefreshToken() => _storage.read(key: 'refresh_token');
  
  Future<void> clearTokens() async {
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    // Only clear ReClaim specific prefs if we want to preserve other data, 
    // but usually logout clears everything.
    await prefs.clear();
  }

  Future<void> _migrateFromSharedPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final at = prefs.getString('access_token');
      final rt = prefs.getString('refresh_token');

      if (at != null || rt != null) {
        if (at != null) await _storage.write(key: 'access_token', value: at);
        if (rt != null) await _storage.write(key: 'refresh_token', value: rt);

        await prefs.remove('access_token');
        await prefs.remove('refresh_token');
      }
    } catch (_) {}
  }
}
