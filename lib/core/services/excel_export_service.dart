// Esporta lo stato locale dell'app in un file Excel (.xlsx) che funge da
// "database" ispezionabile finché non è collegato un vero backend.
//
// Fogli generati:
//   • Ordini di Lavoro   — tutti gli OdL (mock/locali)
//   • Avvisi             — tutti gli avvisi
//   • Preventivi         — un preventivo per riga (Avviso o OdL)
//   • Materiali preventivo — materiali dei preventivi (uno per riga)
//
// Il salvataggio è delegato a `saveExcel` (import condizionale): scrittura su
// file system su mobile/desktop, download nel browser su web.

import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../domain/entities/entities.dart';
import 'excel_saver_io.dart' if (dart.library.html) 'excel_saver_web.dart';

class ExcelExportService {
  ExcelExportService._();
  static final ExcelExportService instance = ExcelExportService._();

  /// Costruisce il workbook e lo salva. Ritorna il percorso (mobile) o il nome
  /// del file scaricato (web).
  Future<String> exportDatabase({
    required List<WorkOrder> ordini,
    required List<NotificationAvviso> avvisi,
    required List<AvvisoExtension> extensions,
  }) async {
    final excel = Excel.createExcel();

    _sheetOrdini(excel, ordini);
    _sheetAvvisi(excel, avvisi);
    _sheetPreventivi(excel, extensions);
    _sheetMateriali(excel, extensions);

    // Rimuove il foglio di default vuoto creato da createExcel().
    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final data = excel.encode();
    if (data == null) {
      throw Exception('Generazione del file Excel fallita');
    }

    final now = DateTime.now();
    final stamp = '${now.year}${_2(now.month)}${_2(now.day)}'
        '_${_2(now.hour)}${_2(now.minute)}';
    return saveExcel(Uint8List.fromList(data), 'wfm_database_$stamp.xlsx');
  }

  void _row(Sheet s, List<String> values) =>
      s.appendRow(values.map((v) => TextCellValue(v)).toList());

  void _sheetOrdini(Excel excel, List<WorkOrder> ordini) {
    final s = excel['Ordini di Lavoro'];
    _row(s, [
      'Codice', 'Tipo', 'Descrizione', 'Stato', 'Appuntamento', 'Cliente',
      'Telefono', 'Indirizzo', 'Sede tecnica', 'CID tecnico', 'Avviso SAP',
      'Stato sync',
    ]);
    for (final o in ordini) {
      _row(s, [
        o.externalCode,
        o.woType,
        o.woTypeDescription,
        o.status.label,
        _d(o.appointmentDate),
        o.customer.fullName,
        o.customer.telefono ?? '',
        o.address.full,
        o.sedeTecnica,
        o.cidAssegnato ?? '',
        o.notificationNumberSap ?? '',
        o.localStatus.name,
      ]);
    }
  }

  void _sheetAvvisi(Excel excel, List<NotificationAvviso> avvisi) {
    final s = excel['Avvisi'];
    _row(s, [
      'Numero', 'Tipo', 'Descrizione', 'Priorità', 'Stato', 'Cliente',
      'Indirizzo', 'OdL collegato',
    ]);
    for (final a in avvisi) {
      _row(s, [
        a.numeroAvviso,
        a.tipo,
        a.descrizione,
        a.priorita,
        a.stato,
        a.customer.fullName,
        a.address.full,
        a.ordineDiLavoro ?? '',
      ]);
    }
  }

  void _sheetPreventivi(Excel excel, List<AvvisoExtension> exts) {
    final s = excel['Preventivi'];
    _row(s, [
      'Chiave (Avviso/OdL)', 'Numero preventivo', 'Stato', 'N. materiali',
      'Firmato da', 'Data firma',
    ]);
    for (final e in exts) {
      final p = e.preventivo;
      if (p == null) continue;
      _row(s, [
        e.avvisoNumero,
        p.numeroPreventivo.isEmpty ? p.id : p.numeroPreventivo,
        p.stato.label,
        p.materiali.length.toString(),
        p.firma?.nomeFirmatario ?? '',
        p.firma != null ? _d(p.firma!.firmataIl) : '',
      ]);
    }
  }

  void _sheetMateriali(Excel excel, List<AvvisoExtension> exts) {
    final s = excel['Materiali preventivo'];
    _row(s, [
      'Chiave (Avviso/OdL)', 'Codice', 'Descrizione', 'Quantità', 'Unità',
    ]);
    for (final e in exts) {
      final p = e.preventivo;
      if (p == null) continue;
      for (final m in p.materiali) {
        _row(s, [
          e.avvisoNumero,
          m.codice,
          m.descrizione,
          m.quantita.toString(),
          m.unitaMisura,
        ]);
      }
    }
  }

  String _d(DateTime? d) =>
      d == null ? '' : '${_2(d.day)}/${_2(d.month)}/${d.year}';
  String _2(int n) => n.toString().padLeft(2, '0');
}
