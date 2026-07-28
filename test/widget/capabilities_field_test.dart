// Il comportamento che tiene in piedi tutta la modalità SAP: un campo che il
// servizio non espone deve restare VISIBILE e spento, non sparire.
//
// La trappola è FormGrid: filtra i figli con hideIfEmpty + valore vuoto, che è
// esattamente la forma di un campo non alimentato. Senza l'eccezione su
// `unavailable`, tutto il lavoro sarebbe invisibile — e nessuno se ne
// accorgerebbe, perché "sparito" e "mai renderizzato" hanno lo stesso aspetto.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_mobile/core/config/capabilities.dart';
import 'package:wfm_mobile/core/widgets/widgets.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
  );
}

void main() {
  group('FieldRow.unavailable', () {
    testWidgets('mostra n/d invece del trattino di un campo vuoto',
        (tester) async {
      await _pump(
        tester,
        const FieldRow(
          label: 'Codice Cliente',
          value: '',
          unavailable: true,
          unavailableReason: 'Dato non ancora esposto dal servizio SAP',
        ),
      );

      expect(find.text('CODICE CLIENTE'), findsOneWidget);
      expect(find.text('n/d'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('vince su hideIfEmpty: il campo resta visibile', (tester) async {
      await _pump(
        tester,
        const FieldRow(
          label: 'Referente',
          value: '',
          hideIfEmpty: true,
          unavailable: true,
        ),
      );

      // Con hideIfEmpty da solo il widget sparirebbe. Qui deve restare.
      expect(find.text('REFERENTE'), findsOneWidget);
      expect(find.text('n/d'), findsOneWidget);
    });

    testWidgets('senza unavailable, hideIfEmpty continua a nascondere',
        (tester) async {
      await _pump(
        tester,
        const FieldRow(label: 'Referente', value: '', hideIfEmpty: true),
      );

      expect(find.text('REFERENTE'), findsNothing);
    });

    testWidgets('un campo alimentato mostra il valore', (tester) async {
      await _pump(tester, const FieldRow(label: 'Numero ODL', value: '60000661'));

      expect(find.text('60000661'), findsOneWidget);
      expect(find.text('n/d'), findsNothing);
    });
  });

  group('FormGrid', () {
    testWidgets('non filtra i campi unavailable pur essendo vuoti',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FormGrid(children: [
              FieldRow(
                  label: 'Codice Cliente',
                  value: '',
                  hideIfEmpty: true,
                  unavailable: true),
              FieldRow(
                  label: 'Telefono',
                  value: '',
                  hideIfEmpty: true,
                  unavailable: true),
            ]),
          ),
        ),
      ));

      expect(find.text('CODICE CLIENTE'), findsOneWidget);
      expect(find.text('TELEFONO'), findsOneWidget);
      expect(find.text('n/d'), findsNWidgets(2));
    });

    testWidgets('continua a filtrare i campi vuoti ordinari', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FormGrid(children: [
              FieldRow(label: 'Presente', value: 'X'),
              FieldRow(label: 'Assente', value: '', hideIfEmpty: true),
            ]),
          ),
        ),
      ));

      expect(find.text('PRESENTE'), findsOneWidget);
      expect(find.text('ASSENTE'), findsNothing);
    });
  });

  group('CapabilityGate', () {
    testWidgets('sezione alimentata: nessun banner, contenuto intatto',
        (tester) async {
      await _pump(
        tester,
        const CapabilityGate(
          enabled: true,
          reason: 'motivo',
          child: Text('contenuto'),
        ),
      );

      expect(find.text('contenuto'), findsOneWidget);
      expect(find.textContaining('Sezione non disponibile'), findsNothing);
    });

    testWidgets('sezione spenta: banner col motivo, contenuto ancora costruito',
        (tester) async {
      await _pump(
        tester,
        const CapabilityGate(
          enabled: false,
          reason: 'Dati non disponibile',
          child: Text('contenuto'),
        ),
      );

      // Il banner mostra il solo motivo, senza prefisso "Sezione non disponibile".
      expect(find.text('Dati non disponibile'), findsOneWidget);
      // Il codice della sezione non è cancellato: continua a essere costruito,
      // solo spento. Riaccendere la capability lo riporta in funzione.
      expect(find.text('contenuto'), findsOneWidget);
      expect(find.byType(IgnorePointer), findsWidgets);
    });
  });

  group('Capabilities', () {
    test('una chiave sconosciuta vale true: meglio un campo vuoto che una '
        'sezione sparita per un refuso', () {
      const caps = Capabilities.allEnabled;
      expect(caps.has('chiave.inesistente'), isTrue);
      expect(caps.has(Cap.odlCliente), isTrue);
    });

    test('fromJson legge modo, sorgente e campi', () {
      final caps = Capabilities.fromJson(const {
        'mode': 'sap',
        'source': 'ZWFMT_SERVIZIO_PM',
        'fields': {'odl.cliente': false, 'odl.operazioni': true},
      });

      expect(caps.isSapMode, isTrue);
      expect(caps.has(Cap.odlCliente), isFalse);
      expect(caps.has(Cap.odlOperazioni), isTrue);
      expect(caps.unavailableReason, 'Dati non disponibile');
    });

    test('modo excel: nessuna sezione spenta', () {
      final caps = Capabilities.fromJson(const {
        'mode': 'excel',
        'source': 'excel',
        'fields': <String, dynamic>{},
      });

      expect(caps.isSapMode, isFalse);
      expect(caps.has(Cap.odlCliente), isTrue);
    });
  });
}
