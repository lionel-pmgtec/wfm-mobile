// Provider pour la réassignation d'un ODL à un autre opérateur.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user.dart';
import 'anagrafica_provider.dart';

// ─── Lista operatori disponibili (dal Cruscotto via anagrafica/tecnici) ─────

final availableOperatorsProvider = FutureProvider<List<AppUser>>((ref) async {
  return ref.watch(techniciansProvider('').future);
});

// ─── Stato della riasignazione ────────────────────────────────────────────────

class ReassignState {
  final bool isLoading;
  final String? error;
  final bool success;

  const ReassignState({
    this.isLoading = false,
    this.error,
    this.success = false,
  });

  ReassignState copyWith({bool? isLoading, String? error, bool? success}) =>
      ReassignState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        success: success ?? this.success,
      );
}

class ReassignNotifier extends StateNotifier<ReassignState> {
  ReassignNotifier() : super(const ReassignState());

  /// Réassigne un ODL à un opérateur — branchera le backend via repository.
  Future<void> reassign({
    required String orderCode,
    required AppUser operator,
    String? note,
  }) async {
    state = state.copyWith(isLoading: true, error: null, success: false);
    try {
      // TODO: chiamare il workOrderRepository.reassign(orderCode, operator.cid, note)
      await Future.delayed(const Duration(milliseconds: 800)); // Simula API
      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() => state = const ReassignState();
}

final reassignProvider =
    StateNotifierProvider<ReassignNotifier, ReassignState>(
  (ref) => ReassignNotifier(),
);
