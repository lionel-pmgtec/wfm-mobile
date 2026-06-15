// Appuntamento OdL (spec).
//
// Modello unificato per "appuntamento fissato" e "appuntamento effettuato":
//   - fissato : data + ora pianificate, modalità (presenza / telefono / video)
//   - effettuato : esito (riuscito / impossibile / rinviato), causa, motivo,
//                  cliente presente (checkbox)

import 'package:flutter/material.dart';

enum AppuntamentoModalita {
  presenza,
  telefono,
  video;

  String get label => switch (this) {
        AppuntamentoModalita.presenza => 'In presenza',
        AppuntamentoModalita.telefono => 'Telefono',
        AppuntamentoModalita.video => 'Video',
      };

  IconData get icon => switch (this) {
        AppuntamentoModalita.presenza => Icons.handshake_outlined,
        AppuntamentoModalita.telefono => Icons.phone_outlined,
        AppuntamentoModalita.video => Icons.video_call_outlined,
      };
}

enum AppuntamentoEsito {
  riuscito,
  impossibile,
  rinviato,
  clienteAssente;

  String get label => switch (this) {
        AppuntamentoEsito.riuscito => 'Riuscito',
        AppuntamentoEsito.impossibile => 'Impossibile',
        AppuntamentoEsito.rinviato => 'Rinviato',
        AppuntamentoEsito.clienteAssente => 'Cliente assente',
      };

  Color get color => switch (this) {
        AppuntamentoEsito.riuscito => const Color(0xFF2E7D32),
        AppuntamentoEsito.impossibile => const Color(0xFFD32F2F),
        AppuntamentoEsito.rinviato => const Color(0xFFFF9800),
        AppuntamentoEsito.clienteAssente => const Color(0xFF7B1FA2),
      };

  IconData get icon => switch (this) {
        AppuntamentoEsito.riuscito => Icons.check_circle_outline,
        AppuntamentoEsito.impossibile => Icons.cancel_outlined,
        AppuntamentoEsito.rinviato => Icons.event_repeat_outlined,
        AppuntamentoEsito.clienteAssente => Icons.person_off_outlined,
      };
}

class OdlAppuntamento {
  final String id;
  // Fissato
  final DateTime dataFissata;
  final String oraFissata; // "HH:mm"
  final AppuntamentoModalita modalita;
  // Effettuato (opzionale fino all'esito)
  final DateTime? dataEffettuato;
  final String? oraEffettuato;
  final AppuntamentoEsito? esito;
  final String? causa;
  final String? motivo;
  final bool clientePresente;
  final String note;
  final DateTime createdAt;

  const OdlAppuntamento({
    required this.id,
    required this.dataFissata,
    this.oraFissata = '',
    this.modalita = AppuntamentoModalita.presenza,
    this.dataEffettuato,
    this.oraEffettuato,
    this.esito,
    this.causa,
    this.motivo,
    this.clientePresente = false,
    this.note = '',
    required this.createdAt,
  });

  bool get isEffettuato => esito != null;

  OdlAppuntamento copyWith({
    DateTime? dataFissata,
    String? oraFissata,
    AppuntamentoModalita? modalita,
    DateTime? dataEffettuato,
    String? oraEffettuato,
    AppuntamentoEsito? esito,
    String? causa,
    String? motivo,
    bool? clientePresente,
    String? note,
  }) =>
      OdlAppuntamento(
        id: id,
        dataFissata: dataFissata ?? this.dataFissata,
        oraFissata: oraFissata ?? this.oraFissata,
        modalita: modalita ?? this.modalita,
        dataEffettuato: dataEffettuato ?? this.dataEffettuato,
        oraEffettuato: oraEffettuato ?? this.oraEffettuato,
        esito: esito ?? this.esito,
        causa: causa ?? this.causa,
        motivo: motivo ?? this.motivo,
        clientePresente: clientePresente ?? this.clientePresente,
        note: note ?? this.note,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'dataFissata': dataFissata.toIso8601String(),
        'oraFissata': oraFissata,
        'modalita': modalita.name,
        'dataEffettuato': dataEffettuato?.toIso8601String(),
        'oraEffettuato': oraEffettuato,
        'esito': esito?.name,
        'causa': causa,
        'motivo': motivo,
        'clientePresente': clientePresente,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory OdlAppuntamento.fromJson(Map json) => OdlAppuntamento(
        id: json['id'] as String,
        dataFissata: DateTime.parse(json['dataFissata'] as String),
        oraFissata: (json['oraFissata'] as String?) ?? '',
        modalita: AppuntamentoModalita.values.firstWhere(
            (m) => m.name == json['modalita'],
            orElse: () => AppuntamentoModalita.presenza),
        dataEffettuato: json['dataEffettuato'] != null
            ? DateTime.tryParse(json['dataEffettuato'] as String)
            : null,
        oraEffettuato: json['oraEffettuato'] as String?,
        esito: json['esito'] != null
            ? AppuntamentoEsito.values.firstWhere(
                (e) => e.name == json['esito'],
                orElse: () => AppuntamentoEsito.riuscito)
            : null,
        causa: json['causa'] as String?,
        motivo: json['motivo'] as String?,
        clientePresente: (json['clientePresente'] as bool?) ?? false,
        note: (json['note'] as String?) ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
