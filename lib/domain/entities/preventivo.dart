// Preventivo (devis) collegato a un Avviso di Servizio.
//
// Ciclo di vita:
//   bozza → inviato → firmato → pagato → chiuso
// (annullato in qualsiasi momento)

import 'package:flutter/material.dart';

import 'enums.dart';
import 'firma_cliente.dart';

/// Stato Preventivo (spec §17).
///
/// Flusso tipico:
///   bozza → inPreparazione → firmato → inviato → approvato/rifiutato →
///   pagato → chiuso.  `annullato` può avvenire in qualsiasi momento.
enum PreventivoStato {
  bozza,
  inPreparazione,
  firmato,
  inviato,
  approvato,
  rifiutato,
  pagato,
  chiuso,
  annullato;

  String get label => switch (this) {
        PreventivoStato.bozza => 'Bozza',
        PreventivoStato.inPreparazione => 'In Preparazione',
        PreventivoStato.firmato => 'Firmato',
        PreventivoStato.inviato => 'Inviato',
        PreventivoStato.approvato => 'Approvato',
        PreventivoStato.rifiutato => 'Rifiutato',
        PreventivoStato.pagato => 'Pagato',
        PreventivoStato.chiuso => 'Chiuso',
        PreventivoStato.annullato => 'Annullato',
      };

  Color get color => switch (this) {
        PreventivoStato.bozza => const Color(0xFF757575),
        PreventivoStato.inPreparazione => const Color(0xFF00838F),
        PreventivoStato.firmato => const Color(0xFF6A1B9A),
        PreventivoStato.inviato => const Color(0xFF1976D2),
        PreventivoStato.approvato => const Color(0xFF2E7D32),
        PreventivoStato.rifiutato => const Color(0xFFD32F2F),
        PreventivoStato.pagato => const Color(0xFF2E7D32),
        PreventivoStato.chiuso => const Color(0xFF455A64),
        PreventivoStato.annullato => const Color(0xFFD32F2F),
      };

  IconData get icon => switch (this) {
        PreventivoStato.bozza => Icons.edit_note_rounded,
        PreventivoStato.inPreparazione => Icons.pending_actions_outlined,
        PreventivoStato.firmato => Icons.draw_outlined,
        PreventivoStato.inviato => Icons.send_outlined,
        PreventivoStato.approvato => Icons.thumb_up_outlined,
        PreventivoStato.rifiutato => Icons.thumb_down_outlined,
        PreventivoStato.pagato => Icons.payments_outlined,
        PreventivoStato.chiuso => Icons.lock_outlined,
        PreventivoStato.annullato => Icons.cancel_outlined,
      };

  bool get isFinal =>
      this == PreventivoStato.chiuso ||
      this == PreventivoStato.annullato ||
      this == PreventivoStato.rifiutato;
}

class PreventivoMateriale {
  final String codice;
  final String descrizione;
  final num quantita;
  final String unitaMisura;
  final num prezzoUnitario;
  final String classificazione;

  const PreventivoMateriale({
    required this.codice,
    required this.descrizione,
    required this.quantita,
    this.unitaMisura = 'PZ',
    required this.prezzoUnitario,
    this.classificazione = '-NONE-',
  });

  num get totale => quantita * prezzoUnitario;

  PreventivoMateriale copyWith({
    num? quantita,
    num? prezzoUnitario,
    String? classificazione,
  }) =>
      PreventivoMateriale(
        codice: codice,
        descrizione: descrizione,
        quantita: quantita ?? this.quantita,
        unitaMisura: unitaMisura,
        prezzoUnitario: prezzoUnitario ?? this.prezzoUnitario,
        classificazione: classificazione ?? this.classificazione,
      );

  Map<String, dynamic> toJson() => {
        'codice': codice,
        'descrizione': descrizione,
        'quantita': quantita,
        'unitaMisura': unitaMisura,
        'prezzoUnitario': prezzoUnitario,
        'classificazione': classificazione,
      };

  factory PreventivoMateriale.fromJson(Map json) => PreventivoMateriale(
        codice: json['codice'] as String,
        descrizione: json['descrizione'] as String,
        quantita: (json['quantita'] as num),
        unitaMisura: (json['unitaMisura'] as String?) ?? 'PZ',
        prezzoUnitario: (json['prezzoUnitario'] as num),
        classificazione: (json['classificazione'] as String?) ?? '-NONE-',
      );
}

class Preventivo {
  final String id;
  final String avvisoNumero;
  final String numeroPreventivo; // display-friendly (spec §7)
  final PreventivoStato stato;
  final String motivo;
  final String classificazioneFiscale;
  final String settoreMerceologico;
  final String numeroOrdineSd;
  final List<PreventivoMateriale> materiali;
  final FirmaCliente? firma;
  final String? pdfPath; // path locale al PDF generato
  final DateTime? dataInvio;
  final DateTime? dataApprovazioneCliente;
  final DateTime? dataPagamento;
  final num aliquotaIva; // es. 22 = 22%
  final String? noteRifiuto; // se rifiutato dal cliente

  // ── Dati Preventivo (spec RP) ──────────────────────────────────────────
  final TipoRichiestaPreventivo? tipoRichiesta;
  final String? descrizioneLavoriRichiesti;
  final DateTime? dataSopralluogo;
  final String? tecnicoSopralluogo;
  final String? cidCollegato;
  final bool odlGenerato;

  // ── Totali aggiuntivi (spec ODL Preventivo) ────────────────────────────
  final num totaleManodopera; // ore × tariffa
  final num totaleTrasferta;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Preventivo({
    required this.id,
    required this.avvisoNumero,
    this.numeroPreventivo = '',
    this.stato = PreventivoStato.bozza,
    this.motivo = '',
    this.classificazioneFiscale = '',
    this.settoreMerceologico = '',
    this.numeroOrdineSd = '',
    this.materiali = const [],
    this.firma,
    this.pdfPath,
    this.dataInvio,
    this.dataApprovazioneCliente,
    this.dataPagamento,
    this.aliquotaIva = 22,
    this.noteRifiuto,
    this.tipoRichiesta,
    this.descrizioneLavoriRichiesti,
    this.dataSopralluogo,
    this.tecnicoSopralluogo,
    this.cidCollegato,
    this.odlGenerato = false,
    this.totaleManodopera = 0,
    this.totaleTrasferta = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Preventivo.bozza(String avvisoNumero) {
    final now = DateTime.now();
    final ts = now.millisecondsSinceEpoch;
    return Preventivo(
      id: 'PREV-$ts',
      avvisoNumero: avvisoNumero,
      // Numero leggibile: PREV-AAAAMMGG-####
      numeroPreventivo:
          'PREV-${now.year}${now.month.toString().padLeft(2, "0")}${now.day.toString().padLeft(2, "0")}-${(ts % 10000).toString().padLeft(4, "0")}',
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Totale materiali (somma riga).
  num get totaleMateriali =>
      materiali.fold<num>(0, (acc, m) => acc + m.totale);

  /// Totale imponibile = materiali + manodopera + trasferta.
  num get totaleSenzaIva =>
      totaleMateriali + totaleManodopera + totaleTrasferta;

  num get importoIva => totaleSenzaIva * aliquotaIva / 100;

  num get totaleConIva => totaleSenzaIva + importoIva;

  bool get hasMateriali => materiali.isNotEmpty;
  bool get hasFirma => firma != null;
  bool get hasPdf => pdfPath != null && pdfPath!.isNotEmpty;

  Preventivo copyWith({
    String? numeroPreventivo,
    PreventivoStato? stato,
    String? motivo,
    String? classificazioneFiscale,
    String? settoreMerceologico,
    String? numeroOrdineSd,
    List<PreventivoMateriale>? materiali,
    FirmaCliente? firma,
    bool clearFirma = false,
    String? pdfPath,
    bool clearPdf = false,
    DateTime? dataInvio,
    DateTime? dataApprovazioneCliente,
    DateTime? dataPagamento,
    num? aliquotaIva,
    String? noteRifiuto,
    TipoRichiestaPreventivo? tipoRichiesta,
    String? descrizioneLavoriRichiesti,
    DateTime? dataSopralluogo,
    String? tecnicoSopralluogo,
    String? cidCollegato,
    bool? odlGenerato,
    num? totaleManodopera,
    num? totaleTrasferta,
  }) =>
      Preventivo(
        id: id,
        avvisoNumero: avvisoNumero,
        numeroPreventivo: numeroPreventivo ?? this.numeroPreventivo,
        stato: stato ?? this.stato,
        motivo: motivo ?? this.motivo,
        classificazioneFiscale:
            classificazioneFiscale ?? this.classificazioneFiscale,
        settoreMerceologico: settoreMerceologico ?? this.settoreMerceologico,
        numeroOrdineSd: numeroOrdineSd ?? this.numeroOrdineSd,
        materiali: materiali ?? this.materiali,
        firma: clearFirma ? null : (firma ?? this.firma),
        pdfPath: clearPdf ? null : (pdfPath ?? this.pdfPath),
        dataInvio: dataInvio ?? this.dataInvio,
        dataApprovazioneCliente:
            dataApprovazioneCliente ?? this.dataApprovazioneCliente,
        dataPagamento: dataPagamento ?? this.dataPagamento,
        aliquotaIva: aliquotaIva ?? this.aliquotaIva,
        noteRifiuto: noteRifiuto ?? this.noteRifiuto,
        tipoRichiesta: tipoRichiesta ?? this.tipoRichiesta,
        descrizioneLavoriRichiesti:
            descrizioneLavoriRichiesti ?? this.descrizioneLavoriRichiesti,
        dataSopralluogo: dataSopralluogo ?? this.dataSopralluogo,
        tecnicoSopralluogo: tecnicoSopralluogo ?? this.tecnicoSopralluogo,
        cidCollegato: cidCollegato ?? this.cidCollegato,
        odlGenerato: odlGenerato ?? this.odlGenerato,
        totaleManodopera: totaleManodopera ?? this.totaleManodopera,
        totaleTrasferta: totaleTrasferta ?? this.totaleTrasferta,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'avvisoNumero': avvisoNumero,
        'numeroPreventivo': numeroPreventivo,
        'stato': stato.name,
        'motivo': motivo,
        'classificazioneFiscale': classificazioneFiscale,
        'settoreMerceologico': settoreMerceologico,
        'numeroOrdineSd': numeroOrdineSd,
        'materiali': materiali.map((m) => m.toJson()).toList(),
        'firma': firma?.toJson(),
        'pdfPath': pdfPath,
        'dataInvio': dataInvio?.toIso8601String(),
        'dataApprovazioneCliente':
            dataApprovazioneCliente?.toIso8601String(),
        'dataPagamento': dataPagamento?.toIso8601String(),
        'aliquotaIva': aliquotaIva,
        'noteRifiuto': noteRifiuto,
        'tipoRichiesta': tipoRichiesta?.name,
        'descrizioneLavoriRichiesti': descrizioneLavoriRichiesti,
        'dataSopralluogo': dataSopralluogo?.toIso8601String(),
        'tecnicoSopralluogo': tecnicoSopralluogo,
        'cidCollegato': cidCollegato,
        'odlGenerato': odlGenerato,
        'totaleManodopera': totaleManodopera,
        'totaleTrasferta': totaleTrasferta,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Preventivo.fromJson(Map json) => Preventivo(
        id: json['id'] as String,
        avvisoNumero: json['avvisoNumero'] as String,
        numeroPreventivo:
            (json['numeroPreventivo'] as String?) ?? '',
        stato: PreventivoStato.values.firstWhere(
            (s) => s.name == json['stato'],
            orElse: () => PreventivoStato.bozza),
        motivo: (json['motivo'] as String?) ?? '',
        classificazioneFiscale:
            (json['classificazioneFiscale'] as String?) ?? '',
        settoreMerceologico: (json['settoreMerceologico'] as String?) ?? '',
        numeroOrdineSd: (json['numeroOrdineSd'] as String?) ?? '',
        materiali: ((json['materiali'] as List?) ?? [])
            .map((e) => PreventivoMateriale.fromJson(e as Map))
            .toList(),
        firma: json['firma'] != null
            ? FirmaCliente.fromJson(json['firma'] as Map)
            : null,
        pdfPath: json['pdfPath'] as String?,
        dataInvio: json['dataInvio'] != null
            ? DateTime.tryParse(json['dataInvio'] as String)
            : null,
        dataApprovazioneCliente: json['dataApprovazioneCliente'] != null
            ? DateTime.tryParse(json['dataApprovazioneCliente'] as String)
            : null,
        dataPagamento: json['dataPagamento'] != null
            ? DateTime.tryParse(json['dataPagamento'] as String)
            : null,
        aliquotaIva: (json['aliquotaIva'] as num?) ?? 22,
        noteRifiuto: json['noteRifiuto'] as String?,
        tipoRichiesta: json['tipoRichiesta'] != null
            ? TipoRichiestaPreventivo.values.firstWhere(
                (t) => t.name == json['tipoRichiesta'],
                orElse: () => TipoRichiestaPreventivo.nuovaInstallazione)
            : null,
        descrizioneLavoriRichiesti:
            json['descrizioneLavoriRichiesti'] as String?,
        dataSopralluogo: json['dataSopralluogo'] != null
            ? DateTime.tryParse(json['dataSopralluogo'] as String)
            : null,
        tecnicoSopralluogo: json['tecnicoSopralluogo'] as String?,
        cidCollegato: json['cidCollegato'] as String?,
        odlGenerato: (json['odlGenerato'] as bool?) ?? false,
        totaleManodopera: (json['totaleManodopera'] as num?) ?? 0,
        totaleTrasferta: (json['totaleTrasferta'] as num?) ?? 0,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
