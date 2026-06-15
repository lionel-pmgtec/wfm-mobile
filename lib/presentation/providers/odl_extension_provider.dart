// Provider per OdlExtension — dati locali editabili dell'OdL.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entities.dart';
import 'core_providers.dart';

class OdlExtensionNotifier extends StateNotifier<OdlExtension> {
  OdlExtensionNotifier(this._ref, String odlCode)
      : super(OdlExtension.empty(odlCode)) {
    _load(odlCode);
  }

  final Ref _ref;

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
