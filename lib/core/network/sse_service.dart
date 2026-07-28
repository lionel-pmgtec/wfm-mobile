// Client SSE (Server-Sent Events) verso il backend del collega (cruscotto).
//
// Il backend espone GET /api/stream: uno snapshot iniziale e poi eventi
// `ordini` / `avvisi` / `reset` quando SAP spinge nuovi dati. Qui apriamo lo
// stream con Dio (ResponseType.stream) e lo riconvertiamo in eventi tipati.
//
// Riconnessione automatica: se lo stream cade (rete/VPN/backend riavviato) si
// riprova dopo un breve attesa, finché il servizio non viene chiuso.

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

class SseEvent {
  final String event; // 'snapshot' | 'ordini' | 'avvisi' | 'reset' | 'message'
  final String data; // payload JSON grezzo (può essere ignorato: usiamo l'evento come trigger)
  const SseEvent(this.event, this.data);
}

class SseService {
  final Dio dio;
  final String path;

  SseService(this.dio, {this.path = '/stream'});

  final _controller = StreamController<SseEvent>.broadcast();
  Stream<SseEvent> get events => _controller.stream;

  bool _closed = false;
  bool _running = false;

  /// Avvia (idempotente) il loop di connessione con riconnessione automatica.
  void start() {
    if (_running || _closed) return;
    _running = true;
    _loop();
  }

  Future<void> _loop() async {
    while (!_closed) {
      try {
        final resp = await dio.get<ResponseBody>(
          path,
          options: Options(
            responseType: ResponseType.stream,
            // SSE è long-lived: niente timeout in ricezione.
            receiveTimeout: Duration.zero,
            headers: {'Accept': 'text/event-stream'},
          ),
        );
        await _readFrames(resp.data!.stream);
      } catch (_) {
        // rete/VPN/backend giù: si ritenta dopo l'attesa sotto.
      }
      if (_closed) break;
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  /// Parsing minimale del formato SSE: linee `event:` e `data:`, frame separati
  /// da riga vuota. Per questo backend ogni evento ha una sola riga `data:`.
  Future<void> _readFrames(Stream<List<int>> byteStream) async {
    var buffer = '';
    var eventName = 'message';
    await for (final chunk in utf8.decoder.bind(byteStream)) {
      if (_closed) return;
      buffer += chunk;
      int nl;
      while ((nl = buffer.indexOf('\n')) >= 0) {
        final line = buffer.substring(0, nl).replaceAll('\r', '');
        buffer = buffer.substring(nl + 1);
        if (line.isEmpty) {
          eventName = 'message';
          continue;
        }
        if (line.startsWith(':')) continue; // commento/keep-alive
        if (line.startsWith('event:')) {
          eventName = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          if (!_controller.isClosed) {
            _controller.add(SseEvent(eventName, line.substring(5).trim()));
          }
        }
      }
    }
  }

  void close() {
    _closed = true;
    if (!_controller.isClosed) _controller.close();
  }
}
