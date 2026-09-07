import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final _storage = const FlutterSecureStorage();
  late final Dio _dio;

  Dio get dio => _dio;

  Future<void> init() async {
    final token = await _storage.read(key: 'token');
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final t = await _storage.read(key: 'token');
        if (t != null) {
          options.headers['Authorization'] = 'Bearer $t';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ));
  }

  Future<void> setToken(String token) async {
    await _storage.write(key: 'token', value: token);
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<void> clearToken() async {
    await _storage.delete(key: 'token');
    _dio.options.headers.remove('Authorization');
  }
}
