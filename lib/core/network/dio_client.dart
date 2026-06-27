import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

class RequestLock {
  Future<void> _lock = Future.value();

  Future<T> synchronized<T>(Future<T> Function() action) async {
    final previous = _lock;
    final completer = Completer<void>();
    _lock = completer.future;
    try {
      await previous;
      return await action();
    } finally {
      completer.complete();
    }
  }
}

class DioClient {
  late final Dio _dio;
  final RequestLock _lock = RequestLock();
  String? _baseUrl;

  DioClient() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(milliseconds: AppConstants.requestTimeoutMs),
        receiveTimeout: const Duration(milliseconds: AppConstants.requestTimeoutMs),
        sendTimeout: const Duration(milliseconds: AppConstants.requestTimeoutMs),
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ));
    }
  }

  void setBaseUrl(String url) {
    _baseUrl = url;
  }

  String? get baseUrl => _baseUrl;

  bool get isConfigured => _baseUrl != null;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    if (!isConfigured) throw Exception("DioClient is not configured with a base URL");
    return _lock.synchronized(() async {
      try {
        return await _dio.get<T>(
          '$_baseUrl$path',
          queryParameters: queryParameters,
        );
      } on DioException catch (e) {
        throw _handleDioError(e);
      }
    });
  }

  Future<Response<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    if (!isConfigured) throw Exception("DioClient is not configured with a base URL");
    return _lock.synchronized(() async {
      try {
        return await _dio.post<T>(
          '$_baseUrl$path',
          data: data,
          queryParameters: queryParameters,
        );
      } on DioException catch (e) {
        throw _handleDioError(e);
      }
    });
  }

  Exception _handleDioError(DioException e) {
    String message = "Erro de conexão";
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      message = "Tempo limite de conexão esgotado";
    } else if (e.type == DioExceptionType.badResponse) {
      final data = e.response?.data;
      if (data is Map && data.containsKey('error')) {
        message = data['error'].toString();
      } else {
        message = "Erro no servidor (Código: ${e.response?.statusCode})";
      }
    } else if (e.type == DioExceptionType.connectionError) {
      message = "Não foi possível conectar à MediCaixa. Verifique a rede.";
    }
    return Exception(message);
  }
}
