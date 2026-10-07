// Passaggio di un OdL a un altro operatore (POST /work-orders/:id/reassign).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user.dart';
import 'anagrafica_provider.dart';
import 'work_orders_provider.dart';

// ─── Lista operatori disponibili (dal Cruscotto via anagrafica/tecnici) ─────

final availableOperatorsProvider = FutureProvider<List<AppUser>>((ref) async {
  return ref.watch(techniciansProvider('').future);
});

// ─── Stato della riasignazione ────────────────────────────────────────────────

class ReassignState {
  final bool isLoading;
  final String? error;
  final bool success;

  /// Com'è andata (valorizzato quando [success]).
  final EsitoRiassegnazione? esito;

  const ReassignState({
    this.isLoading = false,
    this.error,
    this.success = false,
    this.esito,
  });

  ReassignState copyWith(
          {bool? isLoading,
          String? error,
          bool? success,
          EsitoRiassegnazione? esito}) =>
      ReassignState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        success: success ?? this.success,
        esito: esito ?? this.esito,
      );
}

class ReassignNotifier extends StateNotifier<ReassignState> {
  final WorkOrderActions _actions;
  ReassignNotifier(this._actions) : super(const ReassignState());

  Future<void> reassign({
    required String orderCode,
    required AppUser operator,
    String? note,
  }) async {
    state = state.copyWith(isLoading: true, error: null, success: false);
    final res = await _actions.reassign(orderCode, operator.cid, note: note);
    if (!mounted) return;
    state = res.isSuccess
        ? state.copyWith(
            isLoading: false, success: true, esito: res.valueOrNull)
        : state.copyWith(isLoading: false, error: res.failureOrNull?.message);
  }

  void reset() => state = const ReassignState();
}

final reassignProvider =
    StateNotifierProvider<ReassignNotifier, ReassignState>(
  (ref) => ReassignNotifier(ref.read(workOrderActionsProvider)),
);
