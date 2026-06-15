// AvvisoExtension — dati locali (editabili dall'app) che arricchiscono
// un Avviso di Servizio SAP read-only.
//
// Tutti i sotto-moduli (preventivo, permessi, lavori cliente, documenti,
// sospensioni locali, note) sono raccolti qui. La persistenza è in Hive
// (1 box per "avviso_extension", chiave = numero avviso).

import 'package:flutter/material.dart';

import 'lavoro_cliente.dart';
import 'pagamento.dart';
import 'permesso.dart';
import 'preventivo.dart';
import 'suspension.dart';

/// Categoria del documento aggiunto dall'app (spec §13).
enum AvvisoDocumentoCategoria {
  fotoCantiere,
  documentoCliente,
  verbale,
  schedaTecnica,
  permesso,
  preventivoPdf,
  altro;

  String get label => switch (this) {
        AvvisoDocumentoCategoria.fotoCantiere => 'Foto cantiere',
        AvvisoDocumentoCategoria.documentoCliente => 'Documento cliente',
        AvvisoDocumentoCategoria.verbale => 'Verbale',
        AvvisoDocumentoCategoria.schedaTecnica => 'Scheda tecnica',
        AvvisoDocumentoCategoria.permesso => 'Permesso',
        AvvisoDocumentoCategoria.preventivoPdf => 'Preventivo PDF',
        AvvisoDocumentoCategoria.altro => 'Altro',
      };

  IconData get icon => switch (this) {
        AvvisoDocumentoCategoria.fotoCantiere => Icons.photo_camera_outlined,
        AvvisoDocumentoCategoria.documentoCliente => Icons.person_outlined,
        AvvisoDocumentoCategoria.verbale => Icons.assignment_outlined,
        AvvisoDocumentoCategoria.schedaTecnica =>
          Icons.engineering_outlined,
        AvvisoDocumentoCategoria.permesso => Icons.verified_outlined,
        AvvisoDocumentoCategoria.preventivoPdf => Icons.description_outlined,
        AvvisoDocumentoCategoria.altro => Icons.folder_outlined,
      };

  Color get color => switch (this) {
        AvvisoDocumentoCategoria.fotoCantiere => const Color(0xFF1976D2),
        AvvisoDocumentoCategoria.documentoCliente => const Color(0xFF7B1FA2),
        AvvisoDocumentoCategoria.verbale => const Color(0xFF6A1B9A),
        AvvisoDocumentoCategoria.schedaTecnica => const Color(0xFF00838F),
        AvvisoDocumentoCategoria.permesso => const Color(0xFFFF9800),
        AvvisoDocumentoCategoria.preventivoPdf => const Color(0xFF2E7D32),
        AvvisoDocumentoCategoria.altro => const Color(0xFF607D8B),
      };
}

/// Documento aggiunto all'avviso (locale).
class AvvisoDocumento {
  final String id;
  final AvvisoDocumentoCategoria categoria;
  final String fileName;
  final String filePath;
  final String mimeType;
  final int sizeBytes;
  final String? note;
  final DateTime createdAt;

  const AvvisoDocumento({
    required this.id,
    required this.categoria,
    required this.fileName,
    required this.filePath,
    this.mimeType = 'application/octet-stream',
    this.sizeBytes = 0,
    this.note,
    required this.createdAt,
  });

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf => mimeType.contains('pdf');

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoria': categoria.name,
        'fileName': fileName,
        'filePath': filePath,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AvvisoDocumento.fromJson(Map json) => AvvisoDocumento(
        id: json['id'] as String,
        categoria: AvvisoDocumentoCategoria.values.firstWhere(
            (c) => c.name == json['categoria'],
            orElse: () => AvvisoDocumentoCategoria.altro),
        fileName: json['fileName'] as String,
        filePath: json['filePath'] as String,
        mimeType: (json['mimeType'] as String?) ?? 'application/octet-stream',
        sizeBytes: (json['sizeBytes'] as int?) ?? 0,
        note: json['note'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Nota tecnica libera collegata all'avviso.
class AvvisoNota {
  final String id;
  final String testo;
  final String autoreCid;
  final DateTime createdAt;

  const AvvisoNota({
    required this.id,
    required this.testo,
    required this.autoreCid,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'testo': testo,
        'autoreCid': autoreCid,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AvvisoNota.fromJson(Map json) => AvvisoNota(
        id: json['id'] as String,
        testo: json['testo'] as String,
        autoreCid: (json['autoreCid'] as String?) ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Aggregatore dei dati LOCALI di un Avviso di Servizio.
class AvvisoExtension {
  final String avvisoNumero;
  final Preventivo? preventivo;
  final List<Pagamento> pagamenti;
  final List<Permesso> permessi;
  final List<LavoroCliente> lavoriCliente;
  final List<AvvisoDocumento> documenti;
  final List<Suspension> sospensioni;
  final List<AvvisoNota> note;
  final DateTime updatedAt;

  const AvvisoExtension({
    required this.avvisoNumero,
    this.preventivo,
    this.pagamenti = const [],
    this.permessi = const [],
    this.lavoriCliente = const [],
    this.documenti = const [],
    this.sospensioni = const [],
    this.note = const [],
    required this.updatedAt,
  });

  factory AvvisoExtension.empty(String numero) => AvvisoExtension(
        avvisoNumero: numero,
        updatedAt: DateTime.now(),
      );

  /// Totale pagato (somma di tutti i pagamenti riusciti).
  num get totalePagato => pagamenti
      .where((p) => p.esito.name == 'riuscito' || p.esito.name == 'parziale')
      .fold<num>(0, (acc, p) => acc + p.importo);

  AvvisoExtension copyWith({
    Preventivo? preventivo,
    bool clearPreventivo = false,
    List<Pagamento>? pagamenti,
    List<Permesso>? permessi,
    List<LavoroCliente>? lavoriCliente,
    List<AvvisoDocumento>? documenti,
    List<Suspension>? sospensioni,
    List<AvvisoNota>? note,
  }) =>
      AvvisoExtension(
        avvisoNumero: avvisoNumero,
        preventivo: clearPreventivo ? null : (preventivo ?? this.preventivo),
        pagamenti: pagamenti ?? this.pagamenti,
        permessi: permessi ?? this.permessi,
        lavoriCliente: lavoriCliente ?? this.lavoriCliente,
        documenti: documenti ?? this.documenti,
        sospensioni: sospensioni ?? this.sospensioni,
        note: note ?? this.note,
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'avvisoNumero': avvisoNumero,
        'preventivo': preventivo?.toJson(),
        'pagamenti': pagamenti.map((p) => p.toJson()).toList(),
        'permessi': permessi.map((p) => p.toJson()).toList(),
        'lavoriCliente': lavoriCliente.map((l) => l.toJson()).toList(),
        'documenti': documenti.map((d) => d.toJson()).toList(),
        'sospensioni': sospensioni.map(_suspensionToJson).toList(),
        'note': note.map((n) => n.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AvvisoExtension.fromJson(Map json) => AvvisoExtension(
        avvisoNumero: json['avvisoNumero'] as String,
        preventivo: json['preventivo'] != null
            ? Preventivo.fromJson(json['preventivo'] as Map)
            : null,
        pagamenti: ((json['pagamenti'] as List?) ?? [])
            .map((e) => Pagamento.fromJson(e as Map))
            .toList(),
        permessi: ((json['permessi'] as List?) ?? [])
            .map((e) => Permesso.fromJson(e as Map))
            .toList(),
        lavoriCliente: ((json['lavoriCliente'] as List?) ?? [])
            .map((e) => LavoroCliente.fromJson(e as Map))
            .toList(),
        documenti: ((json['documenti'] as List?) ?? [])
            .map((e) => AvvisoDocumento.fromJson(e as Map))
            .toList(),
        sospensioni: ((json['sospensioni'] as List?) ?? [])
            .map((e) => _suspensionFromJson(e as Map))
            .toList(),
        note: ((json['note'] as List?) ?? [])
            .map((e) => AvvisoNota.fromJson(e as Map))
            .toList(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  // ── Suspension JSON helpers (Suspension non ha to/from JSON nativi) ──
  static Map<String, dynamic> _suspensionToJson(Suspension s) => {
        'id': s.id,
        'parentCode': s.parentCode,
        'type': s.type.name,
        'cause': s.cause,
        'note': s.note,
        'startDateTime': s.startDateTime.toIso8601String(),
        'endDateTime': s.endDateTime?.toIso8601String(),
        'authorCid': s.authorCid,
      };

  static Suspension _suspensionFromJson(Map json) => Suspension(
        id: json['id'] as String,
        parentCode: json['parentCode'] as String,
        type: SuspensionType.values.firstWhere(
            (t) => t.name == json['type'],
            orElse: () => SuspensionType.altro),
        cause: (json['cause'] as String?) ?? '',
        note: (json['note'] as String?) ?? '',
        startDateTime: DateTime.parse(json['startDateTime'] as String),
        endDateTime: json['endDateTime'] != null
            ? DateTime.tryParse(json['endDateTime'] as String)
            : null,
        authorCid: (json['authorCid'] as String?) ?? '',
      );
}
