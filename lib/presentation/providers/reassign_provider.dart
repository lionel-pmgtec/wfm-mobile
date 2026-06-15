// Provider pour la réassignation d'un ODL à un autre opérateur.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/enums.dart';

// ─── Lista operatori disponibili (mock — vera collegato con backend) ────────

final availableOperatorsProvider = FutureProvider<List<AppUser>>((ref) async {
  // Simulazione ritardo rete
  await Future.delayed(const Duration(milliseconds: 400));
  return [
    const AppUser(
      cid: 'TEC001',
      nome: 'Marco',
      cognome: 'Rossi',
      workCenter: 'WC-ANCONA',
      role: UserRole.tecnico,
    ),
    const AppUser(
      cid: 'TEC002',
      nome: 'Luca',
      cognome: 'Bianchi',
      workCenter: 'WC-ANCONA',
      role: UserRole.tecnico,
    ),
    const AppUser(
      cid: 'TEC003',
      nome: 'Sara',
      cognome: 'Conti',
      workCenter: 'WC-JESI',
      role: UserRole.tecnicoSenior,
    ),
    const AppUser(
      cid: 'TEC004',
      nome: 'Paolo',
      cognome: 'Ferrari',
      workCenter: 'WC-SENIGALLIA',
      role: UserRole.tecnico,
    ),
    const AppUser(
      cid: 'TEC005',
      nome: 'Elena',
      cognome: 'Marini',
      workCenter: 'WC-FABRIANO',
      role: UserRole.tecnicoSenior,
    ),
  ];
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
