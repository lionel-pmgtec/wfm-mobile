// Lavoro a carico del cliente — attività che il cliente deve svolgere
// per permettere il completamento dell'intervento.
// Dato LOCALE.

import 'package:flutter/material.dart';

enum LavoroClienteStato {
  daFare,
  inCorso,
  completato,
  nonEseguito;

  String get label => switch (this) {
        LavoroClienteStato.daFare => 'Da fare',
        LavoroClienteStato.inCorso => 'In corso',
        LavoroClienteStato.completato => 'Completato',
        LavoroClienteStato.nonEseguito => 'Non eseguito',
      };

  Color get color => switch (this) {
        LavoroClienteStato.daFare => const Color(0xFF1976D2),
        LavoroClienteStato.inCorso => const Color(0xFFFF9800),
        LavoroClienteStato.completato => const Color(0xFF2E7D32),
        LavoroClienteStato.nonEseguito => const Color(0xFFD32F2F),
      };

  IconData get icon => switch (this) {
        LavoroClienteStato.daFare => Icons.assignment_outlined,
        LavoroClienteStato.inCorso => Icons.hourglass_bottom_rounded,
        LavoroClienteStato.completato => Icons.check_circle_outline,
        LavoroClienteStato.nonEseguito => Icons.cancel_outlined,
      };
}

class LavoroCliente {
  final String id;
  final String descrizione;
  final LavoroClienteStato stato;
  final DateTime? dataPrevista;
  final DateTime? dataRealizzazione;
  final String note;
  final DateTime createdAt;

  const LavoroCliente({
    required this.id,
    required this.descrizione,
    this.stato = LavoroClienteStato.daFare,
    this.dataPrevista,
    this.dataRealizzazione,
    this.note = '',
    required this.createdAt,
  });

  LavoroCliente copyWith({
    String? descrizione,
    LavoroClienteStato? stato,
    DateTime? dataPrevista,
    DateTime? dataRealizzazione,
    String? note,
  }) =>
      LavoroCliente(
        id: id,
        descrizione: descrizione ?? this.descrizione,
        stato: stato ?? this.stato,
        dataPrevista: dataPrevista ?? this.dataPrevista,
        dataRealizzazione: dataRealizzazione ?? this.dataRealizzazione,
        note: note ?? this.note,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'descrizione': descrizione,
        'stato': stato.name,
        'dataPrevista': dataPrevista?.toIso8601String(),
        'dataRealizzazione': dataRealizzazione?.toIso8601String(),
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LavoroCliente.fromJson(Map json) => LavoroCliente(
        id: json['id'] as String,
        descrizione: json['descrizione'] as String,
        stato: LavoroClienteStato.values.firstWhere(
            (s) => s.name == json['stato'],
            orElse: () => LavoroClienteStato.daFare),
        dataPrevista: json['dataPrevista'] != null
            ? DateTime.tryParse(json['dataPrevista'] as String)
            : null,
        dataRealizzazione: json['dataRealizzazione'] != null
            ? DateTime.tryParse(json['dataRealizzazione'] as String)
            : null,
        note: (json['note'] as String?) ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
