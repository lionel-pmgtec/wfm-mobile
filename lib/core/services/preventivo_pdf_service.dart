// Generazione PDF Preventivo — modello classico "a modulo" (form bordato),
// in stile documento ufficiale italiano (griglia di celle etichettate).

//
// Layout:
//   • Banda "VIVA SERVIZI" a tutta larghezza
//   • Griglia di celle bordate con micro-etichette (emittente, cliente,
//     intervento) — come un modulo ufficiale
//   • Tabella materiali bordata (N., Codice, Descrizione, UM, Q.tà)
//   • Riga firme (cliente + operatore) in celle bordate
//   • Nota + footer

import 'dart:io' show Directory, File, Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/entities.dart';

class PreventivoPdfService {
  PreventivoPdfService._();
  static final instance = PreventivoPdfService._();

  static const _primary = PdfColor.fromInt(0xFF1F4788);
  static const _primaryDark = PdfColor.fromInt(0xFF0F2D56);
  static const _white = PdfColor.fromInt(0xFFFFFFFF);
  static const _text = PdfColor.fromInt(0xFF1A2540);
  static const _muted = PdfColor.fromInt(0xFF5A6A85);
  static const _border = PdfColor.fromInt(0xFF6B7686);
  static const _headerBg = PdfColor.fromInt(0xFFEDF1F6);

  static const double _side = 28;

  static const String _emittenteRagione = 'Viva Servizi S.p.A.';
  static const String _emittenteIndirizzo = 'Via del Commercio 29 - 60127 Ancona (AN)';
  static const String _emittentePiva = 'P.IVA 02191510420';
  static const String _emittenteContatti =  'Numero Verde 800 216 172 - info@vivaservizi.it';

  // Logo Viva Servizi (assets/images/logo.png) caricato una sola volta.
  pw.MemoryImage? _logo;

  Future<pw.MemoryImage?> _loadLogo() async {
    if (_logo != null) return _logo;
    try {
      final data = await rootBundle.load('assets/images/logo.png');
      _logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      _logo = null;
    }
    return _logo;
  }

  Future<String?> generaEsalva({
    required NotificationAvviso avviso,
    required Preventivo preventivo,
    String? tecnicoNome,
  }) async {
    if (kIsWeb) return null;
    try {
      final bytes = await genera(
        avviso: avviso,
        preventivo: preventivo,
        tecnicoNome: tecnicoNome,
      );
      final dir = await getApplicationDocumentsDirectory();
      final folder =
          Directory('${dir.path}${Platform.pathSeparator}preventivi');
      if (!await folder.exists()) await folder.create(recursive: true);
      final fileName = 'PREV_${avviso.numeroAvviso}_${preventivo.id}.pdf';
      final file =
          File('${folder.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> genera({
    required NotificationAvviso avviso,
    required Preventivo preventivo,
    String? tecnicoNome,
  }) async {
    final numero = preventivo.numeroPreventivo.isNotEmpty
        ? preventivo.numeroPreventivo
        : preventivo.id;

    final logo = await _loadLogo();

    final doc = pw.Document(
      title: 'Preventivo $numero',
      author: tecnicoNome ?? 'Viva Servizi',
    );

    final c = avviso.customer;
    final indirizzo =
        avviso.indirizzoLavoro ?? avviso.indirizzoOggetto ?? avviso.address;
    final cf = c.codiceFiscale ?? avviso.codiceFiscaleCliente ?? '';
    final nomeCliente = c.isBusiness
        ? (c.ragioneSociale ?? '-')
        : (c.fullName.isEmpty ? '-' : c.fullName);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      footer: (ctx) => _pad(_footer(ctx, tecnicoNome)),
      build: (ctx) => [
        _pad(pw.SizedBox(height: 18)),
        _pad(_intestazione(logo)),
        _pad(pw.SizedBox(height: 8)),

        // ── Dati preventivo ───────────────────────────────────────────────
        _pad(_grid([
          _rigaGrid([
            _cella('Preventivo n.', numero, flex: 2),
            _cella('Data', _fmtDate(preventivo.createdAt), flex: 1),
            _cella('Rif. avviso / OdL', avviso.numeroAvviso, flex: 2),
          ]),
        ])),

        // ── Griglia cliente ───────────────────────────────────────────────
        _pad(_grid([
          _rigaGrid([
            _cella('Cliente', nomeCliente, flex: 3),
            _cella('Codice fiscale / P.IVA', cf, flex: 2),
            _cella('Telefono', c.telefono ?? '', flex: 2),
          ]),
        ])),

        // ── Griglia intervento ────────────────────────────────────────────
        _pad(_grid([
          _rigaGrid([
            _cella('Luogo intervento',
                indirizzo.full.isEmpty ? '-' : indirizzo.full, flex: 4),
            _cella('Sede tecnica', avviso.sedeTecnica ?? '', flex: 3),
          ]),
          _rigaGrid([
            _cella('Oggetto / descrizione lavoro',
                avviso.descrizione.isEmpty ? '-' : avviso.descrizione,
                flex: 1),
          ]),
        ])),

        _pad(pw.SizedBox(height: 10)),

        // ── Tabella materiali ─────────────────────────────────────────────
        _pad(_titoloBarra(
            'MATERIALI NECESSARI ALL\'INTERVENTO (${preventivo.materiali.length})')),
        _pad(_materialiTable(preventivo)),

        _pad(pw.SizedBox(height: 12)),

        // ── Firme (cliente | operatore) ───────────────────────────────────
        _pad(_titoloBarra('FIRME PER PRESA VISIONE')),
        _pad(_grid([
          _rigaGrid([
            _cellaFirma('Firma del cliente', preventivo.firma),
            _cellaFirma('Firma dell\'operatore', preventivo.firmaOperatore),
          ]),
        ])),

        _pad(pw.SizedBox(height: 8)),
        _pad(pw.Text(
            'Documento non fiscale - elenco dei materiali necessari '
            'all\'intervento. Validità 30 giorni dalla data di emissione.',
            style: pw.TextStyle(
                fontSize: 8,
                color: _muted,
                fontStyle: pw.FontStyle.italic))),
      ],
    ));

    return doc.save();
  }

  // ════════════════════════════════════════════════════════════════════
  // BLOCCHI
  // ════════════════════════════════════════════════════════════════════

  /// Intestazione stile "busta paga": società a sinistra, logo incorniciato
  /// a destra, senza banda colorata.
  pw.Widget _intestazione(pw.MemoryImage? logo) {
    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(1.3),
      },
      children: [
        pw.TableRow(children: [
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(_emittenteRagione,
                    style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: _primaryDark)),
                pw.SizedBox(height: 2),
                pw.Text(_emittenteIndirizzo,
                    style: pw.TextStyle(fontSize: 8, color: _muted)),
                pw.Text('$_emittentePiva  ·  $_emittenteContatti',
                    style: pw.TextStyle(fontSize: 8, color: _muted)),
                pw.SizedBox(height: 4),
                pw.Text('PREVENTIVO',
                    style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: _primary,
                        letterSpacing: 2)),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            alignment: pw.Alignment.center,
            child: logo != null
                ? pw.SizedBox(
                    height: 52,
                    child: pw.Image(logo, fit: pw.BoxFit.contain))
                : pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 42,
                        height: 42,
                        decoration: pw.BoxDecoration(
                          color: _primary,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text('VS',
                            style: pw.TextStyle(
                                color: _white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 18)),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('VIVA SERVIZI',
                          style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: _primaryDark,
                              letterSpacing: 1)),
                    ],
                  ),
          ),
        ]),
      ],
    );
  }

  /// Titolo su barra piena (etichetta di sezione del modulo).
  pw.Widget _titoloBarra(String text) => pw.Container(
        width: double.infinity,
        color: _primaryDark,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: _white,
                letterSpacing: 0.5)),
      );

  pw.Widget _materialiTable(Preventivo p) {
    const minRighe = 12; // righe minime per "riempire" il modulo
    final righe = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _headerBg),
        children: [
          _thead('N.', align: pw.Alignment.center),
          _thead('Codice'),
          _thead('Descrizione'),
          _thead('UM', align: pw.Alignment.center),
          _thead('Q.tà', align: pw.Alignment.center),
        ],
      ),
    ];
    for (var i = 0; i < p.materiali.length; i++) {
      righe.add(pw.TableRow(children: [
        _tcell('${i + 1}', align: pw.Alignment.center),
        _tcell(p.materiali[i].codice),
        _tcell(p.materiali[i].descrizione),
        _tcell(p.materiali[i].unitaMisura, align: pw.Alignment.center),
        _tcell('${p.materiali[i].quantita}', align: pw.Alignment.center),
      ]));
    }
    // Righe vuote per completare il modulo.
    for (var i = p.materiali.length; i < minRighe; i++) {
      righe.add(pw.TableRow(children: [
        for (var j = 0; j < 5; j++) pw.Container(height: 15),
      ]));
    }
    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.6),
        1: pw.FlexColumnWidth(1.6),
        2: pw.FlexColumnWidth(5.0),
        3: pw.FlexColumnWidth(0.8),
        4: pw.FlexColumnWidth(0.9),
      },
      children: righe,
    );
  }

  pw.Widget _thead(String text,
          {pw.Alignment align = pw.Alignment.centerLeft}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        alignment: align,
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: _primaryDark)),
      );

  pw.Widget _tcell(String text,
          {pw.Alignment align = pw.Alignment.centerLeft}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        alignment: align,
        child: pw.Text(text, style: pw.TextStyle(fontSize: 9, color: _text)),
      );

  pw.Widget _footer(pw.Context ctx, String? tecnico) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 5, bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
              'Viva Servizi S.p.A. - generato il ${_fmtDateTime(DateTime.now())}'
              '${tecnico != null ? "  ·  $tecnico" : ""}',
              style: pw.TextStyle(fontSize: 7, color: _muted)),
          pw.Text('Pag. ${ctx.pageNumber}/${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 7, color: _muted)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // GRIGLIA (celle etichettate, stile modulo)
  // ════════════════════════════════════════════════════════════════════

  /// Impila più righe-tabella in un'unica griglia continua bordata.
  pw.Widget _grid(List<pw.Widget> righe) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: righe,
      );

  /// Riga della griglia: le celle sono equilibrate secondo il loro flex e
  /// separate da bordi condivisi (Table con TableBorder.all).
  pw.Widget _rigaGrid(List<_Cella> celle) {
    final widths = <int, pw.TableColumnWidth>{};
    for (var i = 0; i < celle.length; i++) {
      widths[i] = pw.FlexColumnWidth(celle[i].flex.toDouble());
    }
    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.6),
      columnWidths: widths,
      children: [
        pw.TableRow(children: [for (final c in celle) c.widget]),
      ],
    );
  }

  _Cella _cella(String label, String value, {int flex = 1}) => _Cella(
        flex: flex,
        widget: pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 6, color: _muted, letterSpacing: 0.3)),
              pw.SizedBox(height: 1),
              pw.Text(value.isEmpty ? '-' : value,
                  style: pw.TextStyle(fontSize: 9, color: _text)),
            ],
          ),
        ),
      );

  _Cella _cellaFirma(String label, FirmaCliente? firma) => _Cella(
        flex: 1,
        widget: pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 6, color: _muted, letterSpacing: 0.3)),
              pw.Container(
                height: 46,
                alignment: pw.Alignment.centerLeft,
                child: firma != null
                    ? pw.Image(pw.MemoryImage(firma.pngBytes),
                        fit: pw.BoxFit.contain)
                    : pw.Text('Da firmare',
                        style: pw.TextStyle(
                            fontSize: 9,
                            color: _muted,
                            fontStyle: pw.FontStyle.italic)),
              ),
              pw.Text(
                  firma != null ? 'Il ${firma.dataFormattata}' : ' ',
                  style: pw.TextStyle(fontSize: 6, color: _muted)),
            ],
          ),
        ),
      );

  /// Applica il margine orizzontale ai contenuti (la banda resta full-width).
  pw.Widget _pad(pw.Widget child) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: _side),
        child: child,
      );

  String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  String _fmtDateTime(DateTime d) {
    return '${_fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

/// Cella con il suo peso (flex) per comporre una riga della griglia.
class _Cella {
  final int flex;
  final pw.Widget widget;
  const _Cella({required this.flex, required this.widget});
}
