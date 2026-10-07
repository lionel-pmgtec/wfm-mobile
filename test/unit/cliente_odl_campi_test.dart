// Sezione CLIENTE della fiche e date SAP vuote.
//
// OdL reale 000060000703: SAP non manda un cliente (CLIENTE vuoto) ma il nome
// sull'indirizzo (INDIRIZZO.NOME = "COND.VIA ROVERETO 20A", il nome del
// BATTIMENTO). Il backend lo copia in customer.nome e in referente, e il
// tablet lo mostrava come "Ragione Sociale" e "Referente". Il numero BP
// 0090196928 arriva sia come codiceCliente sia come codBp. L'appuntamento SAP
// è vuoto ("0000-00-00").
//   - il nome del battimento sta sotto INDIRIZZI come "Nome edificio";
//   - il cliente ha nome solo se SAP manda CLIENTE.NOME/COGNOME;
//   - "Referente" non ripete nessun nome;
//   - "Codice Cliente" e "Cod. BP" sono lo stesso numero: una volta sola;
//   - una data SAP vuota non è "30/11/0001".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/data/models/mappers.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/presentation/features/work_orders/work_order_detail_screen.dart';
import 'package:wfm_mobile/presentation/providers/work_orders_provider.dart';

Map<String, dynamic> _reale({
  Map<String, dynamic>? appuntamento,
  String referente = 'COND.VIA ROVERETO 20A',
  bool conCliente = false,
}) =>
    {
      'externalCode': '000060000703',
      'woType': 'SOST',
      'status': 'RICEVUTO',
      'appointmentDate': '0001-11-30', // quello che il tablet mostrava
      'appointmentStartTime': '',
      'referente': referente,
      'codiceCliente': '0090196928',
      'address': {
        'street': 'VIA ROVERETO',
        'streetNumber': '20',
        'cap': '60124',
        'city': 'ANCONA'
      },
      'customer': {
        'nome': 'COND.VIA ROVERETO 20A',
        'cognome': null,
        'ragioneSociale': null,
        'codBp': '0090196928',
        'codCli': null,
      },
      'datiSap': {
        'APPUNTAMENTO': appuntamento,
        // Come SAP: nessun cliente, il nome è sull'indirizzo.
        'CLIENTE': {'OBJECT_CODE': '0090196928'},
        'INDIRIZZO': {'VIA': 'VIA ROVERETO', 'NOME': 'COND.VIA ROVERETO 20A'},
        if (conCliente)
          'CLIENTE': {
            'OBJECT_CODE': '0090196928',
            'NOME': 'Maria',
            'COGNOME': 'Bianchi'
          },
      },
    };

void main() {
  setUpAll(() => initializeDateFormatting('it_IT', null));

  group('date SAP vuote', () {
    test('appuntamento "0000-00-00" / "00000000": nessuna data', () {
      for (final vuota in ['0000-00-00', '00000000', '0000-00-00T00:00:00']) {
        final o = workOrderFromJson(_reale(
            appuntamento: {'FISSATO_DATA': vuota, 'FISSATO_ORA': '000000'}));
        expect(o.appointmentDate, isNull, reason: vuota);
        expect(o.appointmentStartTime, '', reason: vuota);
      }
    });

    test('ora SAP vuota (000000 / 00:00:00) non è "00:00"', () {
      final o = workOrderFromJson(_reale(appuntamento: {
        'FISSATO_DATA': '2026-10-22',
        'FISSATO_ORA': '00:00:00',
        'FISSATO_ORA_LIMITE': '000000',
      }));
      expect(o.appointmentDate, DateTime(2026, 10, 22));
      expect(o.appointmentStartTime, '');
      expect(o.appointmentEndTime, '');
    });

    test('un appuntamento vero resta com\'è', () {
      final o = workOrderFromJson(_reale(
          appuntamento: {'FISSATO_DATA': '20261022', 'FISSATO_ORA': '093000'}));
      expect(o.appointmentDate, DateTime(2026, 10, 22));
      expect(o.appointmentStartTime, '09:30');
    });

    test('anche le altre date: l\'anno 0001 è scartato', () {
      final j = _reale()
        ..['createdAt'] = '0000-00-00'
        ..['dataEsec'] = '0001-11-30';
      final o = workOrderFromJson(j);
      expect(o.createdAt, isNull);
      expect(o.dataEsec, isNull);
    });
  });

  group('cliente e nome edificio dal record SAP', () {
    test("senza CLIENTE: nessun nome cliente, il nome è dell'indirizzo", () {
      final o = workOrderFromJson(_reale());
      expect(o.customer.fullName, isEmpty);
      expect(o.customer.codBp, '0090196928'); // il BP resta
      expect(o.nomeIndirizzo, 'COND.VIA ROVERETO 20A');
      expect(o.referente, isNull);
    });

    test('con CLIENTE: il cliente è quello di SAP', () {
      final o = workOrderFromJson(_reale(conCliente: true));
      expect(o.customer.fullName, 'Maria Bianchi');
      expect(o.nomeIndirizzo, 'COND.VIA ROVERETO 20A');
    });

    test("l'indirizzo di lavoro ha la precedenza su quello dell'oggetto", () {
      final j = _reale();
      (j['datiSap'] as Map)['INDIRIZZO_LAVORO'] = {'NOME': 'SCALA B', 'NOME2': 'INT. 4'};
      expect(workOrderFromJson(j).nomeIndirizzo, 'SCALA B INT. 4');
    });

    test('copia salvata sul tablet: la separazione resta', () {
      final salvato = workOrderToJson(workOrderFromJson(_reale()));
      expect(salvato.containsKey('datiSap'), isFalse);
      final riletto = workOrderFromJson(salvato);
      expect(riletto.nomeIndirizzo, 'COND.VIA ROVERETO 20A');
      expect(riletto.customer.fullName, isEmpty);
    });
  });

  group('referenteDistinto', () {
    test('uguale al nominativo (anche con maiuscole/spazi): nessun referente',
        () {
      expect(
          referenteDistinto('COND.VIA ROVERETO 20A', 'COND.VIA ROVERETO 20A'),
          isNull);
      expect(referenteDistinto('mario  rossi', 'Mario Rossi'), isNull);
    });
    test('vuoto: nessun referente', () {
      expect(referenteDistinto(null, 'X'), isNull);
      expect(referenteDistinto('  ', 'X'), isNull);
    });
    test('un\'altra persona: si mostra', () {
      expect(referenteDistinto('Luca Verdi', 'COND.VIA ROVERETO 20A'),
          'Luca Verdi');
    });
  });

  group('fiche OdL', () {
    Future<void> apri(WidgetTester t, Map<String, dynamic> json) async {
      await t.binding.setSurfaceSize(const Size(1000, 3000));
      final o = workOrderFromJson(json);
      await t.pumpWidget(ProviderScope(
        overrides: [
          workOrderDetailProvider('000060000703').overrideWith((ref) async => o),
        ],
        child: const MaterialApp(
            home: WorkOrderDetailScreen(code: '000060000703')),
      ));
      await t.pumpAndSettle();
    }

    testWidgets('il nome del battimento sta sotto INDIRIZZI, non come cliente',
        (t) async {
      await apri(t, _reale());
      expect(find.text('NOME EDIFICIO'), findsOneWidget);
      expect(find.text('COND.VIA ROVERETO 20A'), findsOneWidget); // una volta
      expect(find.text('CLIENTE'), findsOneWidget); // solo il titolo di sezione
      expect(find.text('Maria Bianchi'), findsNothing); // nessun cliente da SAP
      expect(find.text('RAGIONE SOCIALE'), findsNothing);
      expect(find.text('REFERENTE'), findsNothing);
      expect(find.text('COD. BP'), findsOneWidget);
      expect(find.text('0090196928'), findsOneWidget);
      expect(find.text('CODICE CLIENTE'), findsNothing);
    });

    testWidgets('con un cliente vero di SAP: Cliente = il cliente, edificio a parte',
        (t) async {
      await apri(t, _reale(conCliente: true));
      expect(find.text('CLIENTE'), findsNWidgets(2)); // titolo + campo
      expect(find.text('Maria Bianchi'), findsOneWidget);
      expect(find.text('NOME EDIFICIO'), findsOneWidget);
      expect(find.text('COND.VIA ROVERETO 20A'), findsOneWidget);
    });

    testWidgets('un referente davvero diverso compare', (t) async {
      await apri(t, _reale(referente: 'Luca Verdi'));
      expect(find.text('REFERENTE'), findsOneWidget);
      expect(find.text('Luca Verdi'), findsOneWidget);
    });

    testWidgets('appuntamento SAP vuoto: nessuna data "0001" nella fiche',
        (t) async {
      await apri(
          t,
          _reale(appuntamento: {
            'FISSATO_DATA': '0000-00-00',
            'FISSATO_ORA': '000000'
          }));
      expect(find.textContaining('0001'), findsNothing);
      expect(find.textContaining('30/11'), findsNothing);
    });
  });
}
