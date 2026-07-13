// Processore della coda di sincronizzazione offline-first.
//
// Rigioca verso il middleware le operazioni accodate mentre il tablet era
// offline (cambi di stato OdL, salvataggi, esiti). In caso di successo rimuove
// l'operazione dalla coda; in caso di errore la marca "failed" con backoff
// esponenziale per il tentativo successivo.
//
// Viene invocato: all'avvio, al ritorno della connettività e dal pulsante
// "Riprova" della schermata Coda di sincronizzazione.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/entities.dart';
import '../../domain/repositories/sync_repository.dart';
import '../../data/datasources/local/local_data_source.dart';
import '../../data/datasources/remote/remote_data_source.dart';

class SyncProcessor {
  final SyncRepository sync;
  final WfmRemoteDataSource remote;
  final WfmLocalDataSource local;

  SyncProcessor(this.sync, this.remote, this.local);

  bool _running = false;

  /// Rigioca le operazioni in coda pronte. Con [force] (retry manuale) ignora il
  /// backoff. Restituisce il numero di operazioni sincronizzate con successo.
  Future<int> process({bool force = false}) async {
    if (_running) return 0;
    _running = true;
    var synced = 0;
    try {
      final now = DateTime.now();
      for (final op in await sync.getQueue()) {
        if (op.status == SyncStatus.success ||
            op.status == SyncStatus.inProgress) {
          continue;
        }
        // Rispetta il backoff (salvo retry manuale forzato).
        if (!force && op.nextRetryAt != null && op.nextRetryAt!.isAfter(now)) {
          continue;
        }

        try {
          final handled = await _replay(op);
          if (handled) {
            await sync.cancel(op.id); // rimuove dalla coda
            synced++;
          }
        } catch (e) {
          final n = op.retryCount + 1;
          final backoff = SyncOperation
              .backoff[n.clamp(0, SyncOperation.backoff.length - 1)];
          // Errore di rete = non è un vero fallimento: resta "in attesa"
          // (ambra) e verrà reinviato. Solo gli errori del server diventano
          // "failed" (rosso, richiede attenzione). Mai il testo grezzo in UI.
          final isNetwork = _isNetwork(e);
          await sync.update(op.copyWith(
            status: isNetwork ? SyncStatus.pending : SyncStatus.failed,
            retryCount: n,
            lastError: _friendlyMessage(e),
            nextRetryAt: DateTime.now().add(backoff),
          ));
          if (kDebugMode) {
            // ignore: avoid_print
            print('[sync] ${op.type.name} ${op.entityId} → $e'); // grezzo solo nei log
          }
        }
      }
    } finally {
      _running = false;
    }
    if (kDebugMode && synced > 0) {
      // ignore: avoid_print
      print('[sync] $synced operazioni sincronizzate');
    }
    return synced;
  }

  /// Esegue la chiamata remota corrispondente. Ritorna false se il tipo non è
  /// gestito (l'operazione resta in coda senza essere marcata errore).
  Future<bool> _replay(SyncOperation op) async {
    switch (op.type) {
      case SyncOperationType.updateStatus:
        final statusName = op.payload['status'] as String?;
        final status = WorkOrderStatus.values
            .firstWhere((s) => s.name == statusName, orElse: () => WorkOrderStatus.inEsecuzione);
        await remote.updateStatus(
          op.entityId,
          status,
          reason: op.payload['reason'] as String?,
          note: op.payload['note'] as String?,
        );
        return true;

      case SyncOperationType.updateWorkOrder:
        final o = local.cachedWorkOrder(op.entityId);
        if (o != null) await remote.updateWorkOrder(o);
        return true;

      case SyncOperationType.createWorkOrder:
        final o = local.cachedWorkOrder(op.entityId);
        if (o != null) await remote.createWorkOrder(o);
        return true;

      case SyncOperationType.submitEsito:
        final e = local.esitoDraft(op.entityId);
        if (e != null) await remote.submitEsito(e);
        return true;

      case SyncOperationType.uploadAttachment:
      case SyncOperationType.submitMeterReading:
      case SyncOperationType.submitMaterials:
      case SyncOperationType.createNotification:
        // Tipi non ancora gestiti dal processore: lasciati in coda.
        return false;
    }
  }

  /// Vero se l'errore è dovuto all'assenza di rete (non a un errore del server).
  bool _isNetwork(Object e) {
    if (e is DioException) {
      return e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.error is SocketException;
    }
    return e is SocketException;
  }

  /// Messaggio comprensibile per l'utente (mai lo stack/DioException grezzo).
  String _friendlyMessage(Object e) {
    if (_isNetwork(e)) return 'In attesa di connessione';
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        return 'Sessione scaduta: effettua di nuovo l\'accesso';
      }
      if (code != null && code >= 500) {
        return 'Servizio momentaneamente non disponibile';
      }
      if (code != null && code >= 400) {
        return 'Operazione rifiutata dal server';
      }
    }
    return 'Errore imprevisto durante l\'invio';
  }
}
