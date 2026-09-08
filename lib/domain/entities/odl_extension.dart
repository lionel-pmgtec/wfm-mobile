// OdlExtension — aggregatore di dati LOCALI dell'OdL (non SAP).
//
// Tutto cio che il tecnico aggiunge sul campo:
//   • attivita registrate (codice + descrizione + stato + note)
//   • appuntamenti fissati/effettuati
//   • sospensioni
//   • firme (cliente + tecnico)
//   • chiusura OdL
//   • note libere
//
// Persistenza Hive (box 'odl_extensions', chiave = numero OdL).

import 'firma_cliente.dart';
import 'material.dart';
import 'odl_appuntamento.dart';
import 'odl_attivita.dart';
import 'odl_chiusura.dart';
import 'suspension.dart';

class OdlNota {
  final String id;
  final String testo;
  final String autoreCid;
  final DateTime createdAt;

  const OdlNota({
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

  factory OdlNota.fromJson(Map json) => OdlNota(
        id: json['id'] as String,
        testo: json['testo'] as String,
        autoreCid: (json['autoreCid'] as String?) ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Ora lavorata su una singola operazione (fase). L'operatore la digita nella
/// scheda Operazioni; alla chiusura la somma delle voci di LAVORO (escluso
/// l'automezzo, che è già la somma) viaggia in POST /esiti come `hoursWorked`.
class OdlOreLavorate {
  final String operationNumber;
  final String description;
  final num hours;
  final bool isAutomezzo;

  const OdlOreLavorate({
    required this.operationNumber,
    this.description = '',
    required this.hours,
    this.isAutomezzo = false,
  });

  Map<String, dynamic> toJson() => {
        'operationNumber': operationNumber,
        'description': description,
        'hours': hours,
        'isAutomezzo': isAutomezzo,
      };

  factory OdlOreLavorate.fromJson(Map json) => OdlOreLavorate(
        operationNumber: (json['operationNumber'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        hours: (json['hours'] as num?) ?? 0,
        isAutomezzo: (json['isAutomezzo'] as bool?) ?? false,
      );
}

class OdlExtension {
  final String odlCode; // externalCode dell'OdL
  final List<OdlAttivita> attivita;
  final List<OdlAppuntamento> appuntamenti;
  final List<Suspension> sospensioni;
  final List<OdlNota> note;
  final FirmaCliente? firmaCliente;
  final FirmaCliente? firmaTecnico;
  final OdlChiusura chiusura;

  /// Materiali impegnati dal tecnico sul campo. Restano sul tablet: il
  /// cruscotto accetta i materiali solo con l'esito, non sull'ordine.
  final List<MaterialUsage> materiali;

  /// Ore effettive per operazione digitate dal tecnico (scheda Operazioni).
  /// Trasmesse alla chiusura come `hoursWorked` (il backend ne salva la somma).
  final List<OdlOreLavorate> ore;

  final DateTime updatedAt;

  const OdlExtension({
    required this.odlCode,
    this.attivita = const [],
    this.appuntamenti = const [],
    this.sospensioni = const [],
    this.note = const [],
    this.firmaCliente,
    this.firmaTecnico,
    this.chiusura = const OdlChiusura(),
    this.materiali = const [],
    this.ore = const [],
    required this.updatedAt,
  });

  factory OdlExtension.empty(String code) => OdlExtension(
        odlCode: code,
        updatedAt: DateTime.now(),
      );

  OdlExtension copyWith({
    List<OdlAttivita>? attivita,
    List<OdlAppuntamento>? appuntamenti,
    List<Suspension>? sospensioni,
    List<OdlNota>? note,
    FirmaCliente? firmaCliente,
    bool clearFirmaCliente = false,
    FirmaCliente? firmaTecnico,
    bool clearFirmaTecnico = false,
    OdlChiusura? chiusura,
    List<MaterialUsage>? materiali,
    List<OdlOreLavorate>? ore,
  }) =>
      OdlExtension(
        odlCode: odlCode,
        attivita: attivita ?? this.attivita,
        appuntamenti: appuntamenti ?? this.appuntamenti,
        sospensioni: sospensioni ?? this.sospensioni,
        note: note ?? this.note,
        firmaCliente: clearFirmaCliente
            ? null
            : (firmaCliente ?? this.firmaCliente),
        firmaTecnico: clearFirmaTecnico
            ? null
            : (firmaTecnico ?? this.firmaTecnico),
        chiusura: chiusura ?? this.chiusura,
        materiali: materiali ?? this.materiali,
        ore: ore ?? this.ore,
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'odlCode': odlCode,
        'attivita': attivita.map((a) => a.toJson()).toList(),
        'appuntamenti': appuntamenti.map((a) => a.toJson()).toList(),
        'sospensioni': sospensioni.map(_suspToJson).toList(),
        'note': note.map((n) => n.toJson()).toList(),
        'firmaCliente': firmaCliente?.toJson(),
        'firmaTecnico': firmaTecnico?.toJson(),
        'chiusura': chiusura.toJson(),
        'materiali': materiali.map(_materialeToJson).toList(),
        'ore': ore.map((o) => o.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory OdlExtension.fromJson(Map json) => OdlExtension(
        odlCode: json['odlCode'] as String,
        attivita: ((json['attivita'] as List?) ?? [])
            .map((e) => OdlAttivita.fromJson(e as Map))
            .toList(),
        appuntamenti: ((json['appuntamenti'] as List?) ?? [])
            .map((e) => OdlAppuntamento.fromJson(e as Map))
            .toList(),
        sospensioni: ((json['sospensioni'] as List?) ?? [])
            .map((e) => _suspFromJson(e as Map))
            .toList(),
        note: ((json['note'] as List?) ?? [])
            .map((e) => OdlNota.fromJson(e as Map))
            .toList(),
        firmaCliente: json['firmaCliente'] != null
            ? FirmaCliente.fromJson(json['firmaCliente'] as Map)
            : null,
        firmaTecnico: json['firmaTecnico'] != null
            ? FirmaCliente.fromJson(json['firmaTecnico'] as Map)
            : null,
        chiusura: json['chiusura'] != null
            ? OdlChiusura.fromJson(json['chiusura'] as Map)
            : const OdlChiusura(),
        materiali: ((json['materiali'] as List?) ?? [])
            .map((e) => _materialeFromJson(e as Map))
            .toList(),
        ore: ((json['ore'] as List?) ?? [])
            .map((e) => OdlOreLavorate.fromJson(e as Map))
            .toList(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  static Map<String, dynamic> _materialeToJson(MaterialUsage m) => {
        'materialCode': m.materialCode,
        'description': m.description,
        'plannedQuantity': m.plannedQuantity,
        'usedQuantity': m.usedQuantity,
        'unitOfMeasure': m.unitOfMeasure,
        'warehouseCode': m.warehouseCode,
      };

  static MaterialUsage _materialeFromJson(Map json) => MaterialUsage(
        materialCode: (json['materialCode'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        plannedQuantity: (json['plannedQuantity'] as num?) ?? 0,
        usedQuantity: (json['usedQuantity'] as num?) ?? 0,
        unitOfMeasure: (json['unitOfMeasure'] as String?) ?? 'PZ',
        warehouseCode: (json['warehouseCode'] as String?) ?? '',
      );

  static Map<String, dynamic> _suspToJson(Suspension s) => {
        'id': s.id,
        'parentCode': s.parentCode,
        'type': s.type.name,
        'cause': s.cause,
        'note': s.note,
        'startDateTime': s.startDateTime.toIso8601String(),
        'endDateTime': s.endDateTime?.toIso8601String(),
        'authorCid': s.authorCid,
      };

  static Suspension _suspFromJson(Map json) => Suspension(
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
