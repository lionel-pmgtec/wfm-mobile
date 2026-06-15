// Generazione PDF Preventivo — stile classico.
//
// Layout in stile italiano sobrio :
//   • Intestazione con dati emittente a sinistra, numero/data a destra
//   • Riquadro "Spett.le" cliente
//   • Tabella riferimenti / indirizzo
//   • Tabella materiali bordata
//   • Totali a destra
//   • Riquadro firma
//   • Footer con condizioni e numero pagina
//
// Niente sfondi colorati ovunque, niente angoli arrotondati :
// solo bordi neri/grigi sottili + un accento blu SAP per titoli e linee.
//
// Font Unicode (Noto Sans) per supportare correttamente €, à, è, ecc.

import 'dart:io' show Directory, File, Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/entities/entities.dart';

class PreventivoPdfService {
  PreventivoPdfService._();
  static final instance = PreventivoPdfService._();

  // Palette sobria : blu SAP per titoli, grigi per bordi e testo secondario.
  static const _primary = PdfColor.fromInt(0xFF1F4788);
  static const _text = PdfColor.fromInt(0xFF1A2540);
  static const _muted = PdfColor.fromInt(0xFF5A6A85);
  static const _border = PdfColor.fromInt(0xFF9AA5B8);
  static const _borderSoft = PdfColor.fromInt(0xFFDDE3EC);

  // Dati emittente (placeholder modificabile).
  static const String _emittenteRagione = 'WFM Servizi Idrici S.p.A.';
  static const String _emittenteIndirizzo =
      'Via dell\'Acquedotto 12 - 60100 Ancona (AN)';
  static const String _emittentePiva = 'P.IVA 02345678901';
  static const String _emittenteContatti =
      'Tel. 071 1234567 - info@wfmservizi.it';

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
      final folder = Directory('${dir.path}${Platform.pathSeparator}preventivi');
      if (!await folder.exists()) await folder.create(recursive: true);
      final fileName =
          'PREV_${avviso.numeroAvviso}_${preventivo.id}.pdf';
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
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final fontItalic = await PdfGoogleFonts.notoSansItalic();

    final numero = preventivo.numeroPreventivo.isNotEmpty
        ? preventivo.numeroPreventivo
        : preventivo.id;

    final doc = pw.Document(
      title: 'Preventivo $numero',
      author: tecnicoNome ?? 'WFM Mobile',
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
        italic: fontItalic,
      ),
    );

    final firma = preventivo.firma;
    final firmaImage =
        firma != null ? pw.MemoryImage(firma.pngBytes) : null;
    final indirizzoLavoro =
        avviso.indirizzoLavoro ?? avviso.indirizzoOggetto ?? avviso.address;

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 30, 40, 35),
      footer: (ctx) => _footer(ctx, tecnicoNome),
      build: (ctx) => [
        // ── INTESTAZIONE EMITTENTE / NUMERO ──────────────────────────
        _intestazione(avviso, preventivo, numero),

        pw.SizedBox(height: 18),

        // ── SPETT.LE CLIENTE ────────────────────────────────────────
        _clienteBlocco(avviso),

        pw.SizedBox(height: 14),

        // ── DATI DOCUMENTO ──────────────────────────────────────────
        _datiDocumento(avviso, preventivo),

        pw.SizedBox(height: 14),

        // ── INDIRIZZO INTERVENTO ───────────────────────────────────
        _labelRow('Indirizzo di intervento:',
            _formattaIndirizzo(indirizzoLavoro)),
        if (indirizzoLavoro.hasCoordinates) ...[
          pw.SizedBox(height: 2),
          _labelRow('Coordinate GPS:', indirizzoLavoro.gpsCoordinates),
        ],

        pw.SizedBox(height: 14),

        // ── DESCRIZIONE LAVORO ─────────────────────────────────────
        _sezioneTitolo('Oggetto / Descrizione lavoro'),
        _bordedBox(
          child: pw.Text(
            avviso.descrizione.isEmpty
                ? '-'
                : avviso.descrizione,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),

        if (preventivo.motivo.isNotEmpty ||
            preventivo.classificazioneFiscale.isNotEmpty ||
            preventivo.settoreMerceologico.isNotEmpty ||
            preventivo.numeroOrdineSd.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          _bordedBox(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (preventivo.motivo.isNotEmpty)
                  _labelInline('Motivo preventivo', preventivo.motivo),
                if (preventivo.classificazioneFiscale.isNotEmpty)
                  _labelInline('Classificazione fiscale',
                      preventivo.classificazioneFiscale),
                if (preventivo.settoreMerceologico.isNotEmpty)
                  _labelInline('Settore merceologico',
                      preventivo.settoreMerceologico),
                if (preventivo.numeroOrdineSd.isNotEmpty)
                  _labelInline(
                      'Numero ordine SD', preventivo.numeroOrdineSd),
              ],
            ),
          ),
        ],

        pw.SizedBox(height: 16),

        // ── TABELLA MATERIALI ──────────────────────────────────────
        _sezioneTitolo(
            'Materiali e prestazioni (${preventivo.materiali.length})'),
        _tabellaMateriali(preventivo),

        pw.SizedBox(height: 10),

        // ── TOTALI ─────────────────────────────────────────────────
        _totaliBox(preventivo),

        pw.SizedBox(height: 16),

        // ── CONDIZIONI ─────────────────────────────────────────────
        _sezioneTitolo('Condizioni e validita'),
        _condizioniBlock(avviso),

        pw.SizedBox(height: 16),

        // ── FIRMA ──────────────────────────────────────────────────
        _sezioneTitolo('Firma del cliente per accettazione'),
        if (firma != null && firmaImage != null)
          _firmaBlock(firma, firmaImage)
        else
          _bordedBox(
            height: 80,
            child: pw.Center(
              child: pw.Text('Da firmare',
                  style: pw.TextStyle(
                      color: _muted,
                      fontStyle: pw.FontStyle.italic,
                      fontSize: 10)),
            ),
          ),

        if (preventivo.stato == PreventivoStato.pagato ||
            preventivo.stato == PreventivoStato.chiuso) ...[
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _primary),
            ),
            child: pw.Text(
                'PAGATO il ${_fmtDate(preventivo.dataPagamento)}',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _primary)),
          ),
        ],
      ],
    ));

    return doc.save();
  }

  // ════════════════════════════════════════════════════════════════════
  // BLOCCHI
  // ════════════════════════════════════════════════════════════════════

  pw.Widget _intestazione(
      NotificationAvviso avviso, Preventivo p, String numero) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Emittente
            pw.Expanded(
              flex: 3,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(_emittenteRagione,
                      style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: _text)),
                  pw.SizedBox(height: 2),
                  pw.Text(_emittenteIndirizzo,
                      style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(_emittentePiva,
                      style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(_emittenteContatti,
                      style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ),
            // Numero documento (riquadro classico in alto a destra)
            pw.Container(
              width: 180,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _border, width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('PREVENTIVO',
                      style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: _primary,
                          letterSpacing: 1.2)),
                  pw.SizedBox(height: 4),
                  pw.Text('N. $numero',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Data: ${_fmtDate(p.createdAt)}',
                      style: const pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(height: 4),
                  pw.Text('Avviso SAP: ${avviso.numeroAvviso}',
                      style: pw.TextStyle(fontSize: 9, color: _muted)),
                  pw.Text('Tipo: ${avviso.sottotipo.code}',
                      style: pw.TextStyle(fontSize: 9, color: _muted)),
                  pw.Text('Stato: ${p.stato.label}',
                      style: pw.TextStyle(fontSize: 9, color: _muted)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: _primary, thickness: 1.2, height: 4),
      ],
    );
  }

  pw.Widget _clienteBlocco(NotificationAvviso avviso) {
    final c = avviso.customer;
    final cf = c.codiceFiscale ?? avviso.codiceFiscaleCliente ?? '';
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Spacer(flex: 2),
        pw.Expanded(
          flex: 3,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _border, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Spett.le',
                    style: pw.TextStyle(fontSize: 9, color: _muted)),
                pw.SizedBox(height: 2),
                pw.Text(
                    c.isBusiness
                        ? (c.ragioneSociale ?? '-')
                        : (c.fullName.isEmpty ? '-' : c.fullName),
                    style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: _text)),
                pw.SizedBox(height: 4),
                if (cf.isNotEmpty)
                  pw.Text('Cod. Fiscale: $cf',
                      style: const pw.TextStyle(fontSize: 9)),
                if ((c.partitaIva ?? '').isNotEmpty)
                  pw.Text('Partita IVA: ${c.partitaIva}',
                      style: const pw.TextStyle(fontSize: 9)),
                if ((c.codBp ?? '').isNotEmpty)
                  pw.Text('Cod. BP: ${c.codBp}',
                      style: pw.TextStyle(fontSize: 9, color: _muted)),
                if ((c.telefono ?? '').isNotEmpty)
                  pw.Text('Tel. ${c.telefono}',
                      style: const pw.TextStyle(fontSize: 9)),
                if ((c.email ?? '').isNotEmpty)
                  pw.Text('Email: ${c.email}',
                      style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _datiDocumento(NotificationAvviso avviso, Preventivo p) {
    final righe = <List<String>>[
      if (avviso.hasOrdineCollegato)
        ['Numero OdL', avviso.ordineDiLavoro ?? ''],
      if ((avviso.contratto ?? '').isNotEmpty)
        ['Contratto', avviso.contratto!],
      if ((avviso.sedeTecnica ?? '').isNotEmpty)
        ['Sede tecnica', avviso.sedeTecnica!],
      if ((avviso.ubicazioneTecnica ?? '').isNotEmpty)
        ['Ubicazione', avviso.ubicazioneTecnica!],
      if ((avviso.equipment ?? '').isNotEmpty)
        ['Equipment', avviso.equipment!],
      if ((avviso.centroLavoro ?? '').isNotEmpty)
        ['Centro lavoro', avviso.centroLavoro!],
      if (avviso.priorita.isNotEmpty) ['Priorita', avviso.priorita],
      if (p.dataInvio != null)
        ['Data invio', _fmtDate(p.dataInvio)],
      if (p.dataApprovazioneCliente != null)
        ['Data approvazione', _fmtDate(p.dataApprovazioneCliente)],
    ];
    if (righe.isEmpty) return pw.SizedBox.shrink();
    // Tabella 2 colonne (label + valore) impacchettata su 2 colonne fisiche.
    return pw.Table(
      border: pw.TableBorder.all(color: _borderSoft, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(3),
      },
      children: [
        for (var i = 0; i < righe.length; i += 2)
          pw.TableRow(children: [
            _datoLabel(righe[i][0]),
            _datoValue(righe[i][1]),
            if (i + 1 < righe.length) _datoLabel(righe[i + 1][0]) else _datoLabel(''),
            if (i + 1 < righe.length) _datoValue(righe[i + 1][1]) else _datoValue(''),
          ]),
      ],
    );
  }

  pw.Widget _datoLabel(String s) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(s,
            style: pw.TextStyle(fontSize: 9, color: _muted)),
      );

  pw.Widget _datoValue(String s) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(s.isEmpty ? '-' : s,
            style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _tabellaMateriali(Preventivo p) {
    if (p.materiali.isEmpty) {
      return _bordedBox(
        height: 40,
        child: pw.Center(
          child: pw.Text('Nessun materiale aggiunto',
              style: pw.TextStyle(
                  color: _muted, fontStyle: pw.FontStyle.italic)),
        ),
      );
    }
    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.0),
        1: pw.FlexColumnWidth(3.4),
        2: pw.FlexColumnWidth(0.7),
        3: pw.FlexColumnWidth(0.6),
        4: pw.FlexColumnWidth(1.2),
        5: pw.FlexColumnWidth(1.3),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: _primary, width: 1.2),
            ),
          ),
          children: [
            _thead('Codice'),
            _thead('Descrizione'),
            _thead('Qta', align: pw.Alignment.center),
            _thead('UM', align: pw.Alignment.center),
            _thead('Prezzo un.', align: pw.Alignment.centerRight),
            _thead('Totale', align: pw.Alignment.centerRight),
          ],
        ),
        for (final m in p.materiali)
          pw.TableRow(children: [
            _tcell(m.codice),
            _tcell(m.descrizione),
            _tcell('${m.quantita}', align: pw.Alignment.center),
            _tcell(m.unitaMisura, align: pw.Alignment.center),
            _tcell(_money(m.prezzoUnitario),
                align: pw.Alignment.centerRight),
            _tcell(_money(m.totale),
                align: pw.Alignment.centerRight, bold: true),
          ]),
      ],
    );
  }

  pw.Widget _thead(String text,
          {pw.Alignment align = pw.Alignment.centerLeft}) =>
      pw.Container(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        alignment: align,
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _primary)),
      );

  pw.Widget _tcell(String text,
          {pw.Alignment align = pw.Alignment.centerLeft,
          bool bold = false}) =>
      pw.Container(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        alignment: align,
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: _text)),
      );

  pw.Widget _totaliBox(Preventivo p) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 240,
          child: pw.Table(
            border: pw.TableBorder.all(color: _border, width: 0.6),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.4),
              1: pw.FlexColumnWidth(1),
            },
            children: [
              _trTotale('Imponibile', _money(p.totaleSenzaIva)),
              _trTotale(
                  'IVA ${p.aliquotaIva.toStringAsFixed(0)}%',
                  _money(p.importoIva)),
              _trTotale('TOTALE', _money(p.totaleConIva), bold: true),
            ],
          ),
        ),
      ],
    );
  }

  pw.TableRow _trTotale(String label, String value, {bool bold = false}) =>
      pw.TableRow(
        decoration: bold
            ? const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: _primary, width: 1.2),
                ),
              )
            : null,
        children: [
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: bold ? 11 : 9,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: bold ? _primary : _muted)),
          ),
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            alignment: pw.Alignment.centerRight,
            child: pw.Text(value,
                style: pw.TextStyle(
                    fontSize: bold ? 12 : 10,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: bold ? _primary : _text)),
          ),
        ],
      );

  pw.Widget _condizioniBlock(NotificationAvviso avviso) {
    return _bordedBox(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _puntoElenco(
              'Validita del presente preventivo: 30 giorni dalla data di emissione.'),
          _puntoElenco(
              'Modalita di pagamento accettate: Contanti, Carta, Bonifico, POS.'),
          _puntoElenco(
              'I prezzi indicati sono comprensivi di IVA come da aliquota in tabella.'),
          _puntoElenco(
              'L\'esecuzione dei lavori e subordinata alla firma di accettazione del cliente.'),
          if (avviso.lavoriACaricoCliente)
            _puntoElenco(
                'Alcuni lavori preliminari restano a carico del cliente.'),
        ],
      ),
    );
  }

  pw.Widget _puntoElenco(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('-  ',
                style: pw.TextStyle(fontSize: 9, color: _muted)),
            pw.Expanded(
              child: pw.Text(text,
                  style: const pw.TextStyle(fontSize: 9)),
            ),
          ],
        ),
      );

  pw.Widget _firmaBlock(FirmaCliente firma, pw.MemoryImage img) {
    return _bordedBox(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            height: 70,
            alignment: pw.Alignment.centerLeft,
            child: pw.Image(img, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(height: 4),
          pw.Divider(color: _borderSoft, height: 4),
          pw.SizedBox(height: 4),
          pw.Text('Firmato da: ${firma.nomeFirmatario}',
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text(
              'Data: ${firma.dataFormattata}    Ora: ${firma.oraFormattata}',
              style: pw.TextStyle(fontSize: 9, color: _muted)),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Context ctx, String? tecnico) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _borderSoft)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
              'Generato il ${_fmtDateTime(DateTime.now())}'
              '${tecnico != null ? "  -  $tecnico" : ""}',
              style: pw.TextStyle(fontSize: 8, color: _muted)),
          pw.Text('Pagina ${ctx.pageNumber} di ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: _muted)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════════════

  pw.Widget _sezioneTitolo(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(text.toUpperCase(),
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _primary,
                letterSpacing: 0.8)),
      );

  pw.Widget _bordedBox(
      {required pw.Widget child, double? height}) {
    return pw.Container(
      height: height,
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border, width: 0.6),
      ),
      child: child,
    );
  }

  pw.Widget _labelRow(String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
              text: '$label ',
              style: pw.TextStyle(fontSize: 10, color: _muted)),
          pw.TextSpan(
              text: value,
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _labelInline(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
                text: '$label: ',
                style: pw.TextStyle(fontSize: 9, color: _muted)),
            pw.TextSpan(
                text: value,
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  String _formattaIndirizzo(Address a) => a.full.isEmpty ? '-' : a.full;

  String _money(num value) =>
      'EUR ${value.toStringAsFixed(2).replaceAll('.', ',')}';

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
