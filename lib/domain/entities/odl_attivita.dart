// Attività dell'OdL (spec).
//
// Una attività rappresenta un singolo step di lavoro registrato dal tecnico
// (codice + descrizione + stato + note).

import 'package:flutter/material.dart';

enum OdlAttivitaStato {
  pianificata,
  inCorso,
  completata,
  annullata;

  String get label => switch (this) {
        OdlAttivitaStato.pianificata => 'Pianificata',
        OdlAttivitaStato.inCorso => 'In corso',
        OdlAttivitaStato.completata => 'Completata',
        OdlAttivitaStato.annullata => 'Annullata',
      };

  Color get color => switch (this) {
        OdlAttivitaStato.pianificata => const Color(0xFF1976D2),
        OdlAttivitaStato.inCorso => const Color(0xFFFF9800),
        OdlAttivitaStato.completata => const Color(0xFF2E7D32),
        OdlAttivitaStato.annullata => const Color(0xFFD32F2F),
      };

  IconData get icon => switch (this) {
        OdlAttivitaStato.pianificata => Icons.event_outlined,
        OdlAttivitaStato.inCorso => Icons.hourglass_bottom_rounded,
        OdlAttivitaStato.completata => Icons.check_circle_outline,
        OdlAttivitaStato.annullata => Icons.cancel_outlined,
      };
}

class OdlAttivita {
  final String id;
  final String codice;
  final String descrizione;
  final OdlAttivitaStato stato;
  final String note;
  final DateTime createdAt;

  const OdlAttivita({
    required this.id,
    required this.codice,
    required this.descrizione,
    this.stato = OdlAttivitaStato.pianificata,
    this.note = '',
    required this.createdAt,
  });

  OdlAttivita copyWith({
    String? codice,
    String? descrizione,
    OdlAttivitaStato? stato,
    String? note,
  }) =>
      OdlAttivita(
        id: id,
        codice: codice ?? this.codice,
        descrizione: descrizione ?? this.descrizione,
        stato: stato ?? this.stato,
        note: note ?? this.note,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'codice': codice,
        'descrizione': descrizione,
        'stato': stato.name,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory OdlAttivita.fromJson(Map json) => OdlAttivita(
        id: json['id'] as String,
        codice: json['codice'] as String,
        descrizione: json['descrizione'] as String,
        stato: OdlAttivitaStato.values.firstWhere(
            (s) => s.name == json['stato'],
            orElse: () => OdlAttivitaStato.pianificata),
        note: (json['note'] as String?) ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
