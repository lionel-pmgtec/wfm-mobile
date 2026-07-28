// I tipi ordine e avviso SONO quelli di SAP: qui si verifica che l'app li
// riconosca tutti.
//
// I codici e le descrizioni vengono dai dati reali del centro SP1, letti il
// 2026-07-17 su una finestra di 90 giorni (15 ordini, 55 avvisi). Prima di
// allora l'app si basava sui tipi ipotizzati in specifica, e 9 ordini su 15 e
// 55 avvisi su 55 finivano silenziosamente in un fallback generico.
//
// Se un giorno questi test falliscono, è perché SAP ha cambiato qualcosa: la
// risposta è aggiornare la tabella, non il test.

import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_mobile/domain/entities/avviso_category.dart';
import 'package:wfm_mobile/domain/entities/work_order.dart';

WorkOrder _odl(String woType) => WorkOrder(externalCode: '1', woType: woType);

void main() {
  group('Tipi ordine reali di SP1', () {
    test('ogni tipo osservato su DG1 è riconosciuto', () {
      // Tutti i tipi realmente presenti su SP1 (estrazione 2025→2026, 153
      // ordini). Nessuno deve cadere nel fallback per assenza dalla tabella:
      // anche quelli lasciati "generico" sono mappati esplicitamente.
      const osservati = [
        'ATTI', 'DISA', 'SOST', 'ZA02', 'SOPA', 'LEAP', 'ZDE2',
        'ZF01', 'ZF02', 'ZF04', 'ZI04', 'ZLIM', 'DMOR',
      ];
      for (final t in osservati) {
        expect(kWorkOrderCategoryBySapType.containsKey(t), isTrue,
            reason: 'Il tipo ordine SAP "$t" esiste su DG1 ma non è mappato');
      }
    });

    test('famiglia ZF classificata come intervento rete (fognatura)', () {
      // ZF04 = "RETI STANDARD FOGNATURA" con scavo/ripristino: intervento rete.
      expect(_odl('ZF01').category, WorkOrderCategory.interventoRete);
      expect(_odl('ZF02').category, WorkOrderCategory.interventoRete);
      expect(_odl('ZF04').category, WorkOrderCategory.interventoRete);
      expect(_odl('ZF02').hasInterventoRete, isTrue);
    });

    test('tipi a semantica non confermata restano generico consapevole', () {
      // Mappati esplicitamente a generico, non per fallback: la scelta è voluta.
      for (final t in ['ZI04', 'ZLIM', 'DMOR']) {
        expect(_odl(t).category, WorkOrderCategory.generico,
            reason: '$t deve restare generico finché SAP non conferma');
      }
    });

    test('ATTI / DISA / SOST — confermati dalle descrizioni SAP', () {
      // "Misuratori - Apertura (sigillo)"
      expect(_odl('ATTI').category, WorkOrderCategory.attivazione);
      expect(_odl('ATTI').hasAttivazione, isTrue);
      expect(_odl('ATTI').hasDettagliCliente, isTrue);
      // "Misuratori - Chiusura (sigillo)"
      expect(_odl('DISA').category, WorkOrderCategory.disattivazione);
      expect(_odl('DISA').hasDisattivazione, isTrue);
      // "Sostituzione per vetustità"
      expect(_odl('SOST').category, WorkOrderCategory.sostituzione);
      expect(_odl('SOST').hasSostituzione, isTrue);
      expect(_odl('SOST').hasDettagliCliente, isTrue);
    });

    test('SOPA e ZA02 sono entrambi interventi rete', () {
      // Descrizione identica sui dati reali: "Perdite Idriche".
      expect(_odl('SOPA').category, WorkOrderCategory.interventoRete);
      expect(_odl('ZA02').category, WorkOrderCategory.interventoRete);
      expect(_odl('SOPA').hasInterventoRete, isTrue);
    });

    test('LEAP è una lettura, non un intervento', () {
      // "Letture aperiodiche acqua".
      expect(_odl('LEAP').category, WorkOrderCategory.lettura);
      expect(_odl('LEAP').hasLettura, isTrue);
      expect(_odl('LEAP').hasInterventoRete, isFalse);
      expect(_odl('LEAP').typeCategoryLabel, 'Lettura contatore');
    });

    /// Il vecchio `woType.startsWith('ZA')` catturava qualunque codice che
    /// iniziasse per ZA. ZDE2 non c'entra con la rete idrica ("Ispezione
    /// depurazione") e non deve essere classificato come tale.
    test('ZDE2 non viene scambiato per un intervento rete', () {
      expect(_odl('ZDE2').category, WorkOrderCategory.generico);
      expect(_odl('ZDE2').hasInterventoRete, isFalse);
    });

    test('un tipo sconosciuto ricade su generico senza rompere nulla', () {
      final w = _odl('XXXX');
      expect(w.category, WorkOrderCategory.generico);
      expect(w.typeCategoryLabel, 'Intervento generico');
      expect(w.hasAttivazione, isFalse);
      expect(w.hasInterventoRete, isFalse);
    });

    test('il codice SAP viene normalizzato, non interpretato', () {
      expect(_odl(' atti ').category, WorkOrderCategory.attivazione);
    });
  });

  group('Tipi avviso reali di SP1', () {
    test('ogni tipo osservato su DG1 è nel registry', () {
      // Estrazione 2025→2026 (190 avvisi): ZP (118), ZN (44), ZH (10), IS (9),
      // RA (4), PA (3), ZF (1), ZM (1). Nessuno deve mostrare il codice grezzo.
      for (final code in ['ZP', 'ZN', 'ZH', 'IS', 'RA', 'PA', 'ZF', 'ZM']) {
        final t = AvvisoSubType.fromCode(code);
        expect(AvvisoSubType.all.any((x) => x.code == code), isTrue,
            reason: 'Il tipo avviso SAP "$code" esiste su DG1 ma non è nel registry');
        expect(t.label, isNot(code),
            reason: 'Il tipo "$code" mostra il codice grezzo invece di un\'etichetta');
      }
    });

    test('ZP — perdite idriche, è un pronto intervento', () {
      final t = AvvisoSubType.fromCode('ZP');
      expect(t.category, AvvisoCategory.prontoIntervento);
      expect(t.label, 'Perdite Idriche');
      // Non deve far partire il flusso preventivo/firma/PDF.
      expect(t.category.hasPreventivoFlow, isFalse);
    });

    /// RA è una pratica amministrativa ("Richiesta abbuono fondo di garanzia").
    /// La classificazione è provvisoria, ma una cosa è certa: NON deve
    /// innescare il flusso preventivo + firma + PDF + pagamento.
    test('RA non innesca il flusso preventivo', () {
      expect(AvvisoSubType.fromCode('RA').category.hasPreventivoFlow, isFalse);
    });

    test('un codice sconosciuto resta identificabile', () {
      final t = AvvisoSubType.fromCode('QQQ');
      expect(t.code, 'QQQ');
      expect(t.category, AvvisoCategory.prontoIntervento);
    });
  });
}
