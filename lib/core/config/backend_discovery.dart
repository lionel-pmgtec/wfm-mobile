import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

class BackendDiscoveryResult {
  final String? baseUrl;
  final int? statusCode;

  const BackendDiscoveryResult(this.baseUrl, this.statusCode);
}

/// Carica l'elenco dei candidati da assets/backend_servers.json e utilizza
/// primo backend che restituisce HTTP 200 dal suo endpoint/api/health esistente.
Future<BackendDiscoveryResult> discoverBackend() async {
  final raw = await rootBundle.loadString('assets/backend_servers.json');
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final servers = (decoded['servers'] as List<dynamic>).cast<String>();
  if (servers.isEmpty) return const BackendDiscoveryResult(null, null);

  final result = Completer<BackendDiscoveryResult>();
  var completedChecks = 0;
  for (final baseUrl in servers) {
    unawaited(() async {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
      ));
      try {
        final normalized = baseUrl.replaceFirst(RegExp(r'/+$'), '');
        final root = normalized.endsWith('/api/v1')
            ? normalized.substring(0, normalized.length - '/api/v1'.length)
            : normalized;
        final healthUrl = '$root/api/health';
        final response = await dio.get<dynamic>(healthUrl,
            options: Options(validateStatus: (_) => true));
        if (response.statusCode == 200 && !result.isCompleted) {
          result.complete(BackendDiscoveryResult(baseUrl, 200));
        }
      } catch (_) {
      // Prova i candidati rimanenti quando questo host non è raggiungibile.
      } finally {
        dio.close();
        completedChecks++;
        if (completedChecks == servers.length && !result.isCompleted) {
          result.complete(const BackendDiscoveryResult(null, null));
        }
      }
    }());
  }
  return result.future;
}
