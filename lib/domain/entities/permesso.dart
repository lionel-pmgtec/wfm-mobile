// Permesso (voirie, scavo, ZTL, ...) collegato a un Avviso di Servizio.
// Dato LOCALE: aggiunto dall'app, non proveniente da SAP.

import 'package:flutter/material.dart';

enum PermessoStato {
  inAttesa,
  approvato,
  rifiutato,
  scaduto;

  String get label => switch (this) {
        PermessoStato.inAttesa => 'In attesa',
        PermessoStato.approvato => 'Approvato',
        PermessoStato.rifiutato => 'Rifiutato',
        PermessoStato.scaduto => 'Scaduto',
      };

  Color get color => switch (this) {
        PermessoStato.inAttesa => const Color(0xFFFF9800),
        PermessoStato.approvato => const Color(0xFF2E7D32),
        PermessoStato.rifiutato => const Color(0xFFD32F2F),
        PermessoStato.scaduto => const Color(0xFF757575),
      };

  IconData get icon => switch (this) {
        PermessoStato.inAttesa => Icons.pending_outlined,
        PermessoStato.approvato => Icons.verified_outlined,
        PermessoStato.rifiutato => Icons.cancel_outlined,
        PermessoStato.scaduto => Icons.timer_off_outlined,
      };
}

class Permesso {
  final String id;
  final String tipo; // es. "Scavo", "Voirie", "ZTL", "Occupazione suolo"
  final String numero; // numero protocollo
  final DateTime? dataInizio;
  final DateTime? dataFine;
  final PermessoStato stato;
  final String? documentoPath; // riferimento file allegato locale
  final String note;
  final DateTime createdAt;

  const Permesso({
    required this.id,
    required this.tipo,
    required this.numero,
    this.dataInizio,
    this.dataFine,
    this.stato = PermessoStato.inAttesa,
    this.documentoPath,
    this.note = '',
    required this.createdAt,
  });

  Permesso copyWith({
    String? tipo,
    String? numero,
    DateTime? dataInizio,
    DateTime? dataFine,
    PermessoStato? stato,
    String? documentoPath,
    String? note,
  }) =>
      Permesso(
        id: id,
        tipo: tipo ?? this.tipo,
        numero: numero ?? this.numero,
        dataInizio: dataInizio ?? this.dataInizio,
        dataFine: dataFine ?? this.dataFine,
        stato: stato ?? this.stato,
        documentoPath: documentoPath ?? this.documentoPath,
        note: note ?? this.note,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': tipo,
        'numero': numero,
        'dataInizio': dataInizio?.toIso8601String(),
        'dataFine': dataFine?.toIso8601String(),
        'stato': stato.name,
        'documentoPath': documentoPath,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Permesso.fromJson(Map json) => Permesso(
        id: json['id'] as String,
        tipo: json['tipo'] as String,
        numero: json['numero'] as String,
        dataInizio: json['dataInizio'] != null
            ? DateTime.tryParse(json['dataInizio'] as String)
            : null,
        dataFine: json['dataFine'] != null
            ? DateTime.tryParse(json['dataFine'] as String)
            : null,
        stato: PermessoStato.values.firstWhere(
            (s) => s.name == json['stato'],
            orElse: () => PermessoStato.inAttesa),
        documentoPath: json['documentoPath'] as String?,
        note: (json['note'] as String?) ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
