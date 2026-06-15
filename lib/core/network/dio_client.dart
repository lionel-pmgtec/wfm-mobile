// Factory del client HTTP (Dio) verso il MIDDLEWARE REST/JSON.
//
// NB: in modalità mock (AppConfig.useMockData == true) questo client NON viene
// usato: i repository restituiscono dati locali. È pronto per il backend:
// quando il middleware sarà disponibile basterà impostare useMockData=false e
// fornire una RemoteDataSource che usa questa istanza Dio.

import 'package:dio/dio.dart';
import '../config/app_config.dart';

/// Astrazione per recuperare il token di sessione corrente (iniettata dal
/// layer auth) senza creare dipendenze circolari.
typedef TokenProvider = Future<String?> Function();

class DioClient {
  final AppConfig config;
  final TokenProvider? tokenProvider;
  late final Dio dio;

  DioClient({required this.config, this.tokenProvider}) {
    dio = Dio(
      BaseOptions(
        baseUrl: config.middlewareBaseUrl,
        connectTimeout: config.connectTimeout,
        receiveTimeout: config.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'sap-client': config.sapClient,
        },
      ),
    );

    dio.interceptors.addAll([
      _AuthInterceptor(tokenProvider),
      _RetryInterceptor(dio),
      if (!config.isProd) LogInterceptor(requestBody: false, responseBody: false),
    ]);
  }
}

/// Aggiunge l'header Authorization: Bearer <token>.
class _AuthInterceptor extends Interceptor {
  final TokenProvider? tokenProvider;
  _AuthInterceptor(this.tokenProvider);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

/// Retry con backoff (cfr. specifiche §12.4).
/// Solo timeout transitorie — connectionError significa server irraggiungibile
/// e non deve essere ritentato automaticamente.
class _RetryInterceptor extends Interceptor {
  final Dio dio;
  static const List<Duration> _delays = [
    Duration(seconds: 0),
    Duration(seconds: 5),
    Duration(seconds: 15),
  ];

  _RetryInterceptor(this.dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final attempt = (err.requestOptions.extra['retry_attempt'] as int?) ?? 0;
    // connectionError = server non raggiungibile: fallire subito senza retry.
    final isRetriable = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout;

    if (isRetriable && attempt < _delays.length - 1) {
      final next = attempt + 1;
      await Future.delayed(_delays[next]);
      err.requestOptions.extra['retry_attempt'] = next;
      try {
        final response = await dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } catch (_) {
        return handler.next(err);
      }
    }
    handler.next(err);
  }
}
