// Provider per OdlExtension — dati locali editabili dell'OdL.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/stock_impegnato_store.dart';
import '../../domain/entities/entities.dart';
import 'core_providers.dart';

class OdlExtensionNotifier extends StateNotifier<OdlExtension> {
  OdlExtensionNotifier(this._ref, String odlCode)
      : super(OdlExtension.empty(odlCode)) {
    _pronto = _load(odlCode);
  }

  final Ref _ref;

  /// Termina quando i dati salvati sono stati letti. Chi modifica l'elenco dei
  /// materiali lo aspetta, altrimenti partirebbe da un elenco vuoto e
  /// cancellerebbe quanto già salvato.
  late final Future<void> _pronto;

  Future<void> _load(String code) async {
    final repo = _ref.read(odlExtensionRepositoryProvider);
    state = await repo.get(code);
  }

  Future<void> _persist(OdlExtension next) async {
    state = next;
    await _ref.read(odlExtensionRepositoryProvider).save(next);
  }

  // ── Attività ────────────────────────────────────────────────────────────
  Future<void> addAttivita(OdlAttivita a) =>
      _persist(state.copyWith(attivita: [...state.attivita, a]));
  Future<void> updateAttivita(OdlAttivita a) => _persist(state.copyWith(
        attivita: [
          for (final x in state.attivita)
            if (x.id == a.id) a else x
        ],
      ));
  Future<void> removeAttivita(String id) => _persist(state.copyWith(
        attivita: state.attivita.where((a) => a.id != id).toList(),
      ));

  // ── Materiali impegnati sul campo ───────────────────────────────────────
  /// Aggiunge i materiali. Lo stesso materiale preso dallo stesso magazzino
  /// NON apre una seconda riga: se c'è già, se ne aumenta la quantità.
  Future<void> addMateriali(List<MaterialUsage> nuovi) async {
    await _pronto;
    final righe = [...state.materiali];
    for (final n in nuovi) {
      final i = righe.indexWhere((m) =>
          m.materialCode == n.materialCode &&
          m.warehouseCode == n.warehouseCode);
      if (i < 0) {
        righe.add(n);
      } else {
        final m = righe[i];
        righe[i] = MaterialUsage(
          materialCode: m.materialCode,
          description: m.description,
          plannedQuantity: m.plannedQuantity + n.plannedQuantity,
          usedQuantity: m.usedQuantity + n.usedQuantity,
          unitOfMeasure: m.unitOfMeasure,
          warehouseCode: m.warehouseCode,
        );
      }
    }
    await _persist(state.copyWith(materiali: righe));
  }

  /// Toglie dall'OdL la riga di un materiale (con quel magazzino): la
  /// quantità torna al magazzino da cui era stata prelevata.
  Future<void> removeRiga(String materialCode, String warehouseCode) async {
    await _pronto;
    final tolte = state.materiali.where((m) =>
        m.materialCode == materialCode && m.warehouseCode == warehouseCode);
    for (final m in tolte) {
      await StockImpegnatoStore.rilascia(
          m.materialCode, m.warehouseCode, m.usedQuantity);
    }
    await _persist(state.copyWith(
      materiali: state.materiali
          .where((m) => !(m.materialCode == materialCode &&
              m.warehouseCode == warehouseCode))
          .toList(),
    ));
  }

  Future<void> removeMateriale(String materialCode) async {
    // Il materiale tolto torna nel magazzino da cui era stato prelevato.
    for (final m in state.materiali.where((m) => m.materialCode == materialCode)) {
      await StockImpegnatoStore.rilascia(
          m.materialCode, m.warehouseCode, m.usedQuantity);
    }
    await _persist(state.copyWith(
      materiali:
          state.materiali.where((m) => m.materialCode != materialCode).toList(),
    ));
  }

  // ── Ore lavorate (scheda Operazioni) ────────────────────────────────────
  Future<void> setOre(List<OdlOreLavorate> ore) =>
      _persist(state.copyWith(ore: ore));

  /// Registra l'ora di "Avvia" (inizio reale sul campo), solo la prima volta:
  /// un "Riprendi" dopo una sospensione non deve azzerare l'inizio. Serve a
  /// precompilare l'orario di inizio nell'esito con l'ora effettiva.
  Future<void> segnaAvvio() {
    if (state.avviatoIl != null) return Future.value();
    return _persist(state.copyWith(avviatoIl: DateTime.now()));
  }

  // ── Appuntamenti ────────────────────────────────────────────────────────
  Future<void> addAppuntamento(OdlAppuntamento a) =>
      _persist(state.copyWith(appuntamenti: [...state.appuntamenti, a]));
  Future<void> updateAppuntamento(OdlAppuntamento a) =>
      _persist(state.copyWith(
        appuntamenti: [
          for (final x in state.appuntamenti)
            if (x.id == a.id) a else x
        ],
      ));
  Future<void> removeAppuntamento(String id) => _persist(state.copyWith(
        appuntamenti:
            state.appuntamenti.where((a) => a.id != id).toList(),
      ));

  // ── Sospensioni ─────────────────────────────────────────────────────────
  Future<void> addSospensione(Suspension s) =>
      _persist(state.copyWith(sospensioni: [...state.sospensioni, s]));
  Future<void> closeSospensione(String id, DateTime endDateTime) =>
      _persist(state.copyWith(
        sospensioni: [
          for (final x in state.sospensioni)
            if (x.id == id) x.copyWith(endDateTime: endDateTime) else x
        ],
      ));
  Future<void> removeSospensione(String id) => _persist(state.copyWith(
        sospensioni:
            state.sospensioni.where((s) => s.id != id).toList(),
      ));

  // ── Firme ───────────────────────────────────────────────────────────────
  Future<void> setFirmaCliente(FirmaCliente f) =>
      _persist(state.copyWith(firmaCliente: f));
  Future<void> clearFirmaCliente() =>
      _persist(state.copyWith(clearFirmaCliente: true));
  Future<void> setFirmaTecnico(FirmaCliente f) =>
      _persist(state.copyWith(firmaTecnico: f));
  Future<void> clearFirmaTecnico() =>
      _persist(state.copyWith(clearFirmaTecnico: true));

  // ── Chiusura ────────────────────────────────────────────────────────────
  Future<void> setChiusura(OdlChiusura c) =>
      _persist(state.copyWith(chiusura: c));

  // ── Note ────────────────────────────────────────────────────────────────
  Future<void> addNota(OdlNota n) =>
      _persist(state.copyWith(note: [...state.note, n]));
  Future<void> removeNota(String id) => _persist(state.copyWith(
        note: state.note.where((n) => n.id != id).toList(),
      ));
}

final odlExtensionProvider =
    StateNotifierProvider.family<OdlExtensionNotifier, OdlExtension, String>(
        (ref, code) => OdlExtensionNotifier(ref, code));
