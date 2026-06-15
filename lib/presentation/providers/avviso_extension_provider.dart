// Provider per AvvisoExtension — dati locali di un Avviso.
//
// AvvisoExtensionNotifier mantiene lo stato locale dell'extension per un
// singolo numero avviso e lo persiste tramite il repository (Hive).
//
// Pattern: family(numeroAvviso) per isolare gli avvisi.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entities.dart';
import 'core_providers.dart';

class AvvisoExtensionNotifier extends StateNotifier<AvvisoExtension> {
  AvvisoExtensionNotifier(this._ref, String numero)
      : super(AvvisoExtension.empty(numero)) {
    _load(numero);
  }

  final Ref _ref;

  Future<void> _load(String numero) async {
    final repo = _ref.read(avvisoExtensionRepositoryProvider);
    state = await repo.get(numero);
  }

  Future<void> _persist(AvvisoExtension next) async {
    state = next;
    await _ref.read(avvisoExtensionRepositoryProvider).save(next);
  }

  // ── Preventivo ──────────────────────────────────────────────────────────
  Future<void> setPreventivo(Preventivo prev) =>
      _persist(state.copyWith(preventivo: prev));

  Future<void> clearPreventivo() =>
      _persist(state.copyWith(clearPreventivo: true));

  // ── Permessi ────────────────────────────────────────────────────────────
  Future<void> addPermesso(Permesso p) =>
      _persist(state.copyWith(permessi: [...state.permessi, p]));

  Future<void> updatePermesso(Permesso p) => _persist(
        state.copyWith(
          permessi: [
            for (final x in state.permessi)
              if (x.id == p.id) p else x
          ],
        ),
      );

  Future<void> removePermesso(String id) => _persist(
        state.copyWith(
          permessi: state.permessi.where((p) => p.id != id).toList(),
        ),
      );

  // ── Lavori Cliente ──────────────────────────────────────────────────────
  Future<void> addLavoroCliente(LavoroCliente l) =>
      _persist(state.copyWith(lavoriCliente: [...state.lavoriCliente, l]));

  Future<void> updateLavoroCliente(LavoroCliente l) => _persist(
        state.copyWith(
          lavoriCliente: [
            for (final x in state.lavoriCliente)
              if (x.id == l.id) l else x
          ],
        ),
      );

  Future<void> removeLavoroCliente(String id) => _persist(
        state.copyWith(
          lavoriCliente:
              state.lavoriCliente.where((l) => l.id != id).toList(),
        ),
      );

  // ── Documenti ───────────────────────────────────────────────────────────
  Future<void> addDocumento(AvvisoDocumento d) =>
      _persist(state.copyWith(documenti: [...state.documenti, d]));

  Future<void> removeDocumento(String id) => _persist(
        state.copyWith(
          documenti: state.documenti.where((d) => d.id != id).toList(),
        ),
      );

  // ── Sospensioni ─────────────────────────────────────────────────────────
  Future<void> addSospensione(Suspension s) =>
      _persist(state.copyWith(sospensioni: [...state.sospensioni, s]));

  Future<void> closeSospensione(String id, DateTime endDateTime) => _persist(
        state.copyWith(
          sospensioni: [
            for (final x in state.sospensioni)
              if (x.id == id) x.copyWith(endDateTime: endDateTime) else x
          ],
        ),
      );

  Future<void> removeSospensione(String id) => _persist(
        state.copyWith(
          sospensioni:
              state.sospensioni.where((s) => s.id != id).toList(),
        ),
      );

  // ── Note ────────────────────────────────────────────────────────────────
  Future<void> addNota(AvvisoNota n) =>
      _persist(state.copyWith(note: [...state.note, n]));

  Future<void> removeNota(String id) => _persist(
        state.copyWith(
          note: state.note.where((n) => n.id != id).toList(),
        ),
      );

  // ── Pagamenti ───────────────────────────────────────────────────────────
  Future<void> addPagamento(Pagamento p) =>
      _persist(state.copyWith(pagamenti: [...state.pagamenti, p]));

  Future<void> removePagamento(String id) => _persist(
        state.copyWith(
          pagamenti: state.pagamenti.where((p) => p.id != id).toList(),
        ),
      );
}

final avvisoExtensionProvider = StateNotifierProvider.family<
    AvvisoExtensionNotifier, AvvisoExtension, String>(
  (ref, numero) => AvvisoExtensionNotifier(ref, numero),
);
