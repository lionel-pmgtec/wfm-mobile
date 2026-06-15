// Chiusura OdL (spec).

import 'package:flutter/material.dart';

enum OdlEsitoIntervento {
  riuscito,
  parziale,
  nonRiuscito;

  String get label => switch (this) {
        OdlEsitoIntervento.riuscito => 'Riuscito',
        OdlEsitoIntervento.parziale => 'Parziale',
        OdlEsitoIntervento.nonRiuscito => 'Non riuscito',
      };

  Color get color => switch (this) {
        OdlEsitoIntervento.riuscito => const Color(0xFF2E7D32),
        OdlEsitoIntervento.parziale => const Color(0xFFFF9800),
        OdlEsitoIntervento.nonRiuscito => const Color(0xFFD32F2F),
      };

  IconData get icon => switch (this) {
        OdlEsitoIntervento.riuscito => Icons.task_alt_outlined,
        OdlEsitoIntervento.parziale => Icons.adjust_outlined,
        OdlEsitoIntervento.nonRiuscito => Icons.report_problem_outlined,
      };
}

class OdlChiusura {
  final OdlEsitoIntervento? esito;
  final bool problemaRisolto;
  final bool daRiprogrammare;
  final DateTime? dataChiusura;
  final String? chiusoDa;
  final String noteFinali;

  const OdlChiusura({
    this.esito,
    this.problemaRisolto = false,
    this.daRiprogrammare = false,
    this.dataChiusura,
    this.chiusoDa,
    this.noteFinali = '',
  });

  factory OdlChiusura.empty() => const OdlChiusura();

  OdlChiusura copyWith({
    OdlEsitoIntervento? esito,
    bool? problemaRisolto,
    bool? daRiprogrammare,
    DateTime? dataChiusura,
    String? chiusoDa,
    String? noteFinali,
  }) =>
      OdlChiusura(
        esito: esito ?? this.esito,
        problemaRisolto: problemaRisolto ?? this.problemaRisolto,
        daRiprogrammare: daRiprogrammare ?? this.daRiprogrammare,
        dataChiusura: dataChiusura ?? this.dataChiusura,
        chiusoDa: chiusoDa ?? this.chiusoDa,
        noteFinali: noteFinali ?? this.noteFinali,
      );

  Map<String, dynamic> toJson() => {
        'esito': esito?.name,
        'problemaRisolto': problemaRisolto,
        'daRiprogrammare': daRiprogrammare,
        'dataChiusura': dataChiusura?.toIso8601String(),
        'chiusoDa': chiusoDa,
        'noteFinali': noteFinali,
      };

  factory OdlChiusura.fromJson(Map json) => OdlChiusura(
        esito: json['esito'] != null
            ? OdlEsitoIntervento.values.firstWhere(
                (e) => e.name == json['esito'],
                orElse: () => OdlEsitoIntervento.riuscito)
            : null,
        problemaRisolto: (json['problemaRisolto'] as bool?) ?? false,
        daRiprogrammare: (json['daRiprogrammare'] as bool?) ?? false,
        dataChiusura: json['dataChiusura'] != null
            ? DateTime.tryParse(json['dataChiusura'] as String)
            : null,
        chiusoDa: json['chiusoDa'] as String?,
        noteFinali: (json['noteFinali'] as String?) ?? '',
      );
}
