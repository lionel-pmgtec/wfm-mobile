// Gestione appuntamenti per OdL (in memoria per l'MVP front-end).
// TODO: deve essere collegato al middleware (servizio appuntamenti / Dati sopralluogo).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/entities.dart';
import 'work_orders_provider.dart';

class AppointmentsController extends StateNotifier<List<Appointment>> {
  final String code;
  AppointmentsController(this.code, List<Appointment> initial) : super(initial);

  void add(Appointment a) => state = [...state, a];

  void update(Appointment a) =>
      state = [for (final x in state) if (x.id == a.id) a else x];

  void setOutcome(String id, AppointmentOutcome outcome, {String? note}) {
    state = [
      for (final x in state)
        if (x.id == id) x.copyWith(outcome: outcome, note: note) else x
    ];
  }
}

/// Family per OdL. Seed iniziale: l'appuntamento fissato dell'OdL (se presente).
final appointmentsProvider = StateNotifierProvider.family<
    AppointmentsController, List<Appointment>, String>((ref, code) {
  final order = ref.watch(workOrderDetailProvider(code)).valueOrNull;
  final seed = <Appointment>[];
  if (order?.appointmentDate != null) {
    seed.add(Appointment(
      id: 'seed-$code',
      workOrderCode: code,
      date: order!.appointmentDate!,
      startTime: order.appointmentStartTime,
      endTime: order.appointmentEndTime,
      inPresenza: true,
    ));
  }
  return AppointmentsController(code, seed);
});
