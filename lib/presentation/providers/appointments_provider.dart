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

/// Dati dell'esito appuntamento (form completo). In-memory come gli
/// appuntamenti: il backend non espone (ancora) una rotta di salvataggio,
/// quindi l'esito viene conservato in locale sul dispositivo e ricaricato alla
/// riapertura della schermata. Nessun dato simulato.
class EsitoAppuntamentoData {
  final DateTime dataSopralluogo;
  final String oraSopralluogo;
  final String esito; // OK / NO / ER / MN
  final String ritiro;
  final String motivo;
  final String? causaCode; // codice dal catalogo backend (/anagrafica/causes)
  final String causaRitardo;
  final String motivoRitardo;
  final bool dispAnticipazione;
  final bool presenzaCliente;

  const EsitoAppuntamentoData({
    required this.dataSopralluogo,
    required this.oraSopralluogo,
    required this.esito,
    this.ritiro = '',
    this.motivo = '',
    this.causaCode,
    this.causaRitardo = '',
    this.motivoRitardo = '',
    this.dispAnticipazione = false,
    this.presenzaCliente = true,
  });
}

class EsitoAppuntamentoController
    extends StateNotifier<EsitoAppuntamentoData?> {
  EsitoAppuntamentoController() : super(null);
  void save(EsitoAppuntamentoData data) => state = data;
}

/// Esito appuntamento salvato in locale, per OdL.
final esitoAppuntamentoProvider = StateNotifierProvider.family<
    EsitoAppuntamentoController, EsitoAppuntamentoData?, String>(
  (ref, code) => EsitoAppuntamentoController(),
);

/// Relevé compteur saisi dans "Gestione contatore" (onglet Lettura). Salvato in
/// locale e trasmesso alla chiusura (nel nodo `letture` di POST /esiti).
class MeterReadingDraft {
  final num reading;
  final String nota;
  final DateTime dateTime;
  const MeterReadingDraft({
    required this.reading,
    this.nota = '',
    required this.dateTime,
  });
}

class MeterReadingController extends StateNotifier<MeterReadingDraft?> {
  MeterReadingController() : super(null);
  void save(MeterReadingDraft d) => state = d;
}

/// Bozza di lettura contatore per OdL.
final meterReadingDraftProvider = StateNotifierProvider.family<
    MeterReadingController, MeterReadingDraft?, String>(
  (ref, code) => MeterReadingController(),
);

/// Family per OdL. Seed iniziale: SOLO un appuntamento realmente fissato.
///
/// ATTENZIONE: il backend (toMobile.ts) calcola `appointmentDate` a cascata e,
/// in mancanza di un vero appuntamento, ricade sulla DATA_INIZIO (data inizio
/// cardine). Quindi `appointmentDate` non è mai null e da solo NON significa
/// "appuntamento fissato": altrimenti ogni OdL appena ricevuto mostrerebbe un
/// appuntamento fantasma mai programmato dal tecnico.
///
/// Discriminante: un appuntamento vero ha un'ORA (`appointmentStartTime`, da
/// FISSATO_ORA o dalla schedulazione del cruscotto); il ripiego su DATA_INIZIO
/// non ne ha. Quindi si semina solo quando c'è un orario.
final appointmentsProvider = StateNotifierProvider.family<
    AppointmentsController, List<Appointment>, String>((ref, code) {
  final order = ref.watch(workOrderDetailProvider(code)).valueOrNull;
  final seed = <Appointment>[];
  final haOrario = (order?.appointmentStartTime ?? '').trim().isNotEmpty;
  if (order?.appointmentDate != null && haOrario) {
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
