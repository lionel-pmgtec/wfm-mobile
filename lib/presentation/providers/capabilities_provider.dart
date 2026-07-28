// Capabilities: quali sezioni la sorgente dati attiva alimenta davvero.
// Interrogate una volta al middleware (GET /capabilities) e lette poi ovunque
// in modo sincrono dalle schermate.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/capabilities.dart';
import 'core_providers.dart';

/// Recupero dal middleware. Non fallisce mai: se l'endpoint non c'è o la rete è
/// giù, ricade su [Capabilities.allEnabled] — un middleware più vecchio dell'app
/// deve continuare a funzionare come prima, non far sparire mezza interfaccia.
final capabilitiesFutureProvider = FutureProvider<Capabilities>((ref) async {
  try {
    return await ref.watch(remoteDataSourceProvider).getCapabilities();
  } catch (_) {
    return Capabilities.allEnabled;
  }
});

/// Lettura sincrona per le schermate.
///
/// Finché la richiesta è in volo vale [Capabilities.allEnabled]: l'interfaccia
/// parte completa e, quando la risposta arriva, le sezioni non alimentate si
/// spengono. Il contrario (partire tutto spento) farebbe lampeggiare le sezioni
/// a ogni avvio.
///
/// Nei test si sovrascrive direttamente questo provider:
/// ```dart
/// ProviderScope(overrides: [capabilitiesProvider.overrideWithValue(...)])
/// ```
final capabilitiesProvider = Provider<Capabilities>((ref) {
  return ref.watch(capabilitiesFutureProvider).maybeWhen(
        data: (c) => c,
        orElse: () => Capabilities.allEnabled,
      );
});
