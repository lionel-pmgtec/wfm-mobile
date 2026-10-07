// Gestione appuntamenti per OdL (in memoria per l'MVP front-end).
// TODO: deve essere collegato al middleware (servizio appuntamenti / Dati sopralluogo).

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
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

  /// Etichetta breve dello stato del rendez-vous secondo l'esito registrato.
  String get statoLabel => switch (esito) {
        'OK' => 'Effettuato',
        'NO' => 'Esito negativo',
        'ER' => 'Errore inserimento',
        'MN' => 'Mancato accesso',
        _ => 'Esito registrato',
      };

  /// Vero se l'appuntamento risulta svolto (esito positivo).
  bool get effettuato => esito == 'OK';

  Map<String, dynamic> toJson() => {
        'dataSopralluogo': dataSopralluogo.toIso8601String(),
        'oraSopralluogo': oraSopralluogo,
        'esito': esito,
        'ritiro': ritiro,
        'motivo': motivo,
        'causaCode': causaCode,
        'causaRitardo': causaRitardo,
        'motivoRitardo': motivoRitardo,
        'dispAnticipazione': dispAnticipazione,
        'presenzaCliente': presenzaCliente,
      };

  factory EsitoAppuntamentoData.fromJson(Map<String, dynamic> j) =>
      EsitoAppuntamentoData(
        dataSopralluogo:
            DateTime.tryParse('${j['dataSopralluogo']}') ?? DateTime.now(),
        oraSopralluogo: (j['oraSopralluogo'] ?? '').toString(),
        esito: (j['esito'] ?? '').toString(),
        ritiro: (j['ritiro'] ?? '').toString(),
        motivo: (j['motivo'] ?? '').toString(),
        causaCode: j['causaCode']?.toString(),
        causaRitardo: (j['causaRitardo'] ?? '').toString(),
        motivoRitardo: (j['motivoRitardo'] ?? '').toString(),
        dispAnticipazione: j['dispAnticipazione'] == true,
        presenzaCliente: j['presenzaCliente'] != false,
      );

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

/// Archivio su disco (Hive) degli esiti appuntamento: "salvato sul dispositivo"
/// deve valere anche dopo la chiusura dell'app, perché l'esito parte solo con la
/// chiusura dell'OdL. Se il box non è aperto (test) resta in memoria.
class EsitoAppuntamentoStore {
  static Box<String>? _box;

  /// [hivePath] serve ai test; in app si usa la cartella di Flutter.
  static Future<void> open({String? hivePath}) async {
    if (hivePath == null) {
      await Hive.initFlutter();
    } else {
      Hive.init(hivePath);
    }
    _box = await Hive.openBox<String>('local_esito_appuntamento');
  }

  static EsitoAppuntamentoData? read(String code) {
    try {
      final s = _box?.get(code);
      if (s == null) return null;
      return EsitoAppuntamentoData.fromJson(
          jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      // Box chiuso o record illeggibile: come se non ci fosse un esito salvato.
      return null;
    }
  }

  static Future<void> write(String code, EsitoAppuntamentoData d) async {
    try {
      await _box?.put(code, jsonEncode(d.toJson()));
    } catch (_) {
      // Un errore di scrittura non deve bloccare la schermata: lo stato in
      // memoria resta valido per la sessione.
    }
  }
}

class EsitoAppuntamentoController
    extends StateNotifier<EsitoAppuntamentoData?> {
  EsitoAppuntamentoController(this.code)
      : super(EsitoAppuntamentoStore.read(code));
  final String code;

  void save(EsitoAppuntamentoData data) {
    state = data;
    EsitoAppuntamentoStore.write(code, data);
  }
}

/// Esito appuntamento salvato in locale, per OdL.
final esitoAppuntamentoProvider = StateNotifierProvider.family<
    EsitoAppuntamentoController, EsitoAppuntamentoData?, String>(
  (ref, code) => EsitoAppuntamentoController(code),
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

/// Bozza di SOSTITUZIONE contatore (OdL SOST), salvata in locale e trasmessa
/// alla chiusura: le due letture (contatore rimosso + nuovo) nel nodo `letture`
/// di POST /esiti, la nuova posizione nel nodo `contatore`. Nessun dato
/// inventato: campi vuoti = non inviati. Il backend dedicato SOST non è ancora
/// pronto, ma questi campi sono quelli che il contratto attuale accetta.
class MeterSubstitutionDraft {
  final num? depositReading; // lettura al deposito (contatore rimosso)
  final String newMatricola; // numero di serie nuovo contatore
  final num? initialReading; // lettura di posa (nuovo contatore)
  final DateTime? posaDate; // data di posa (→ readingDateTime del nuovo)
  final String newProduttore; // produttore nuovo contatore (non ancora esposto)
  final String sealNumber; // numero sigillo
  final String position; // posizione/ubicazione nuovo contatore
  final String positionAdd; // aggiunta ubicazione
  // Ubicazione CORRETTA del contatore esistente/rimosso: SAP non sempre la
  // manda, l'operatore la inserisce/corregge a mano. Solo un riferimento
  // locale: non ha un nodo dedicato nel contratto /esiti.
  final String oldUbicazione;
  final Map<String, String> dynFields; // campi dinamici wo-fields?type=SOST
  final DateTime dateTime;

  const MeterSubstitutionDraft({
    this.depositReading,
    this.newMatricola = '',
    this.initialReading,
    this.posaDate,
    this.newProduttore = '',
    this.sealNumber = '',
    this.position = '',
    this.positionAdd = '',
    this.oldUbicazione = '',
    this.dynFields = const {},
    required this.dateTime,
  });
}

class MeterSubstitutionController
    extends StateNotifier<MeterSubstitutionDraft?> {
  MeterSubstitutionController() : super(null);
  void save(MeterSubstitutionDraft d) => state = d;
}

/// Bozza di sostituzione contatore per OdL.
final meterSubstitutionDraftProvider = StateNotifierProvider.family<
    MeterSubstitutionController, MeterSubstitutionDraft?, String>(
  (ref, code) => MeterSubstitutionController(),
);

/// Family per OdL. Seed iniziale: SOLO l'appuntamento fissato col cliente.
///
/// `order.appointmentDate` è già l'appuntamento vero: il mapper lo legge da
/// `datiSap.APPUNTAMENTO` (workOrderFromJson), non dalla data di pianificazione
/// che il backend mette comunque (oggi, se manca). Un ordine che arriva da
/// SAP/cruscotto senza appuntamento ha quindi `appointmentDate == null` e la
/// lista parte vuota, senza appuntamenti fittizi; con l'appuntamento del
/// cliente compare, con la sua data e (se c'è) la sua ora.
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
