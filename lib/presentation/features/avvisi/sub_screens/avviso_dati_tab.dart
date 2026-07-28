// Tab "Info" — Sezioni complete per categoria :
//
//   PRONTO INTERVENTO (PI) : ZF-PF, ZA01, ZF-ZF01, ZA02
//   ├── DATI AVVISO (CID, categoria, codice guasto, SLA, ...)
//   ├── CLIENTE (codice, referente, cellulare, contratto attivo, ...)
//   ├── INDIRIZZO AVVISO (via, civico, CAP, area tecnica, GPS, ...)
//   ├── INDIRIZZO OGGETTO (sede tecnica, equipment, impianto, ...)
//   ├── DATI TECNICI (stato equipment, matricola, categoria tecnica, ...)
//   └── GESTIONE INTERVENTO (assegnato, squadra, date guasto, stato op, ...)
//
//   RICHIESTA PREVENTIVO (RP) : PA
//   ├── DATI AVVISO (CID, data richiesta, codice guasto, ...)
//   ├── CLIENTE (codice, CF, P.IVA, sede tecnica, GPS, ...)
//   ├── DATI TECNICI (sede, equipment, categoria, stato impianto, ...)
//   ├── INDIRIZZI (Cliente / Oggetto / Lavoro)
//   └── DATI PREVENTIVO (tipo richiesta, sopralluogo, ODL generato, ...)
//
// Tutti i campi sono in sola lettura (dati SAP), marcati col lucchetto.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/capabilities.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../domain/entities/entities.dart';
import '../../../providers/avviso_extension_provider.dart';
import '../../../providers/avvisi_provider.dart';
import '../../../providers/capabilities_provider.dart';
import '../widgets/avviso_widgets.dart';

class AvvisoDatiTab extends ConsumerWidget {
  final NotificationAvviso avviso;
  const AvvisoDatiTab({super.key, required this.avviso});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPI = avviso.categoria == AvvisoCategory.prontoIntervento;
    final ext = ref.watch(avvisoExtensionProvider(avviso.numeroAvviso));
    final editing = ref.watch(avvisoEditModeProvider(avviso.numeroAvviso));
    final caps = ref.watch(capabilitiesProvider);
    final reason = caps.unavailableReason;

    // Riorganizzazione (2026-07-23): in alto ciò che SAP alimenta davvero
    // (dati avviso, dati tecnici, elaborazione operatore); in fondo, collassate,
    // le sezioni che ZWFMT_S_AVVISO NON popola (Cliente, Indirizzi, Gestione
    // Intervento — servirebbero IHPA/ADRC/ILOA). Prima era il contrario: molte
    // sezioni vuote in evidenza e i pochi dati reali sepolti in fondo.
    return ListView(
      padding: kPagePadding,
      children: [
        CategoryBanner(sottotipo: avviso.sottotipo),
        const SizedBox(height: 12),

        // ═══ DATI ALIMENTATI DA SAP ═══════════════════════════════════

        // ── DATI AVVISO ─────────────────────────────────────────────
        WfmCollapsibleSection(
          title: 'DATI AVVISO',
          icon: Icons.info_outline,
          child: isPI
              ? _DatiAvvisoPI(avviso: avviso)
              : _DatiAvvisoRP(avviso: avviso),
        ),

        // ── DATI TECNICI (sede tecnica, centro manut., equipment) ───
        // Portati in alto: contengono i campi realmente valorizzati da SAP.
        WfmCollapsibleSection(
          title: 'DATI TECNICI',
          icon: Icons.precision_manufacturing_outlined,
          child: _DatiTecnici(avviso: avviso),
        ),

        // ── DATI PREVENTIVO (solo RP) ───────────────────────────────
        if (!isPI)
          WfmCollapsibleSection(
            title: 'DATI PREVENTIVO',
            icon: Icons.description_outlined,
            child: _DatiPreventivoRP(
              avviso: avviso,
              preventivo: ext.preventivo,
            ),
          ),

        // ── ELABORAZIONE (operatore — editabile inline con la matita) ─
        WfmCollapsibleSection(
          // La key dipende da `editing`: alla pressione della matita la
          // sezione si ri-crea espansa, così l'operatore vede subito i campi.
          key: ValueKey('elaborazione-$editing'),
          title: 'ELABORAZIONE',
          icon: Icons.edit_note_outlined,
          initiallyExpanded: editing,
          child: _ElaborazioneSection(
            avviso: avviso,
            elaborazione: ext.elaborazione,
          ),
        ),

        // ═══ SEZIONI IN ATTESA DI MAPPATURA SAP ═══════════════════════
        // Oggi ZWFMT_S_AVVISO non le popola, ma il dev SAP le mapperà a breve
        // (IHPA/ADRC per cliente e indirizzi): restano quindi sulla tablet,
        // tenute in fondo e collassate finché non arrivano i dati.
        const SizedBox(height: 8),
        const _SapGapDivider(),

        // ── CLIENTE ─────────────────────────────────────────────────
        // ZWFMT_S_AVVISO non porta fuori nessun dato cliente: servirebbero
        // i partner IHPA + ADRC.
        if (!caps.has(Cap.avvisoCliente) ||
            !avviso.customer.isEmpty ||
            (avviso.referente ?? '').isNotEmpty)
          WfmCollapsibleSection(
            title: 'CLIENTE',
            icon: Icons.person_outline,
            initiallyExpanded: false,
            child: CapabilityGate(
              enabled: caps.has(Cap.avvisoCliente),
              reason: reason,
              child: isPI
                  ? _ClientePI(avviso: avviso)
                  : _ClienteRP(avviso: avviso),
            ),
          ),

        // ── INDIRIZZI (PI: 2 indirizzi separati ; RP: 3 indirizzi) ──
        // Nemmeno gli indirizzi sono esposti: servirebbero ILOA + ADRC.
        if (isPI) ...[
          WfmCollapsibleSection(
            title: 'INDIRIZZO AVVISO',
            icon: Icons.place_outlined,
            initiallyExpanded: false,
            child: CapabilityGate(
              enabled: caps.has(Cap.avvisoIndirizzi),
              reason: reason,
              child: _IndirizzoBlocco(
                address: avviso.address,
                telefonoExtra: avviso.indirizzoAvvisoTelefono,
                areaTecnica: avviso.areaTecnica,
                showGps: true,
              ),
            ),
          ),
          if (!caps.has(Cap.avvisoIndirizzi) ||
              avviso.indirizzoOggetto != null ||
              (avviso.sedeTecnica ?? '').isNotEmpty)
            WfmCollapsibleSection(
              title: 'INDIRIZZO OGGETTO',
              icon: Icons.engineering_outlined,
              initiallyExpanded: false,
              child: CapabilityGate(
                enabled: caps.has(Cap.avvisoIndirizzi),
                reason: reason,
                child: _IndirizzoOggettoPI(avviso: avviso),
              ),
            ),
        ] else
          WfmCollapsibleSection(
            title: 'INDIRIZZI',
            icon: Icons.place_outlined,
            initiallyExpanded: false,
            child: CapabilityGate(
              enabled: caps.has(Cap.avvisoIndirizzi),
              reason: reason,
              child: _IndirizziRP(avviso: avviso),
            ),
          ),

        // ── GESTIONE INTERVENTO (solo PI) ───────────────────────────
        if (isPI)
          WfmCollapsibleSection(
            title: 'GESTIONE INTERVENTO',
            icon: Icons.local_shipping_outlined,
            initiallyExpanded: false,
            child: CapabilityGate(
              enabled: caps.has(Cap.avvisoGestioneIntervento),
              reason: reason,
              child: _GestioneIntervento(avviso: avviso),
            ),
          ),

        const SizedBox(height: 80),
      ],
    );
  }
}

/// Separatore che segna dove finiscono i dati SAP e iniziano le sezioni
/// non alimentate da ZWFMT_S_AVVISO (tenute in fondo, collassate).
class _SapGapDivider extends StatelessWidget {
  const _SapGapDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Divider()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'IN ATTESA DI MAPPATURA SAP',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.textHint,
              ),
            ),
          ),
          Expanded(child: Divider()),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// DATI AVVISO — Pronto Intervento
// ════════════════════════════════════════════════════════════════════

class _DatiAvvisoPI extends StatelessWidget {
  final NotificationAvviso avviso;
  const _DatiAvvisoPI({required this.avviso});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SapLockedField(
            label: 'Numero Avviso',
            value: avviso.numeroAvviso,
            fullWidth: true),
        const SizedBox(height: 6),
        SapLockedField(
            label: 'Descrizione Breve',
            value: avviso.descrizioneBreve ?? avviso.descrizione,
            fullWidth: true,
            hideIfEmpty: false),
        const SizedBox(height: 6),
        if ((avviso.descrizioneEstesa ?? '').isNotEmpty)
          SapLockedField(
              label: 'Descrizione Estesa',
              value: avviso.descrizioneEstesa!,
              fullWidth: true),
        const SizedBox(height: 8),
        FormGrid(children: [
          SapLockedField(
              label: 'Tipo Avviso',
              value: '${avviso.sottotipo.code} - ${avviso.sottotipo.label}',
              hideIfEmpty: false),
          SapLockedField(label: 'CID', value: avviso.cid ?? ''),
          SapLockedField(
              label: 'Categoria',
              value: avviso.categoriaIntervento?.label ?? ''),
          SapLockedField(label: 'Stato Avviso', value: avviso.statoTipo.label),
          // Stato reale SAP (CO_STTXT): codici come MAPE/MELA che lo status
          // applicativo appiattisce sempre a "Creato".
          SapLockedField(
              label: 'Stato SAP',
              value: avviso.statoSap ?? '',
              hideIfEmpty: true),
          SapLockedField(label: 'Priorita', value: avviso.priorita),
          SapLockedField(
              label: 'Canale Apertura',
              value: avviso.canaleApertura?.label ?? ''),
          SapLockedField(
              label: 'Tipo Servizio', value: avviso.tipoServizio?.label ?? ''),
          SapLockedField(label: 'SLA Target', value: avviso.slaTarget ?? ''),
          SapLockedField(
              label: 'Tempo Risposta', value: avviso.tempoRispostaAtteso ?? ''),
          SapLockedField(
              label: 'Codice Guasto', value: avviso.codiceGuasto ?? ''),
          SapLockedField(
              label: 'Codice Causa', value: avviso.codiceCausa ?? ''),
          SapLockedField(
              label: 'Data Apertura',
              value:
                  '${Fmt.date(avviso.dataApertura)} ${avviso.oraApertura ?? ''}'),
          SapLockedField(
              label: 'Data Segnalazione',
              value: Fmt.date(avviso.dataSegnalazione)),
          SapLockedField(
              label: 'Ora Segnalazione', value: avviso.oraSegnalazione ?? ''),
        ]),
        if ((avviso.noteOperatore ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          SapLockedField(
              label: 'Note Operatore',
              value: avviso.noteOperatore!,
              fullWidth: true),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// DATI AVVISO — Richiesta Preventivo
// ════════════════════════════════════════════════════════════════════

class _DatiAvvisoRP extends StatelessWidget {
  final NotificationAvviso avviso;
  const _DatiAvvisoRP({required this.avviso});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SapLockedField(
            label: 'Numero Avviso',
            value: avviso.numeroAvviso,
            fullWidth: true),
        const SizedBox(height: 6),
        SapLockedField(
            label: 'Descrizione Breve',
            value: avviso.descrizioneBreve ?? avviso.descrizione,
            fullWidth: true,
            hideIfEmpty: false),
        const SizedBox(height: 6),
        if ((avviso.descrizioneEstesa ?? '').isNotEmpty)
          SapLockedField(
              label: 'Descrizione Estesa',
              value: avviso.descrizioneEstesa!,
              fullWidth: true),
        const SizedBox(height: 8),
        FormGrid(children: [
          SapLockedField(
              label: 'Tipo Avviso',
              value: '${avviso.sottotipo.code} - ${avviso.sottotipo.label}',
              hideIfEmpty: false),
          SapLockedField(label: 'CID', value: avviso.cid ?? ''),
          SapLockedField(label: 'Categoria', value: 'Richiesta Preventivo'),
          SapLockedField(label: 'Stato Avviso', value: avviso.statoTipo.label),
          SapLockedField(
              label: 'Stato SAP',
              value: avviso.statoSap ?? '',
              hideIfEmpty: true),
          SapLockedField(
              label: 'Data Richiesta', value: Fmt.date(avviso.dataApertura)),
          SapLockedField(
              label: 'Ora Richiesta', value: avviso.oraApertura ?? ''),
          SapLockedField(
              label: 'Codice Guasto', value: avviso.codiceGuasto ?? ''),
          SapLockedField(
              label: 'Codice Causa', value: avviso.codiceCausa ?? ''),
        ]),
        if ((avviso.noteOperatore ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          SapLockedField(
              label: 'Note Operatore',
              value: avviso.noteOperatore!,
              fullWidth: true),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// CLIENTE
// ════════════════════════════════════════════════════════════════════

class _ClientePI extends StatelessWidget {
  final NotificationAvviso avviso;
  const _ClientePI({required this.avviso});

  @override
  Widget build(BuildContext context) {
    final c = avviso.customer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (c.isBusiness)
          SapLockedField(
              label: 'Ragione Sociale',
              value: c.ragioneSociale ?? '',
              fullWidth: true)
        else
          SapLockedField(label: 'Cliente', value: c.fullName, fullWidth: true),
        const SizedBox(height: 8),
        FormGrid(children: [
          SapLockedField(
              label: 'Codice Cliente',
              value: avviso.codiceCliente ?? c.codCli ?? ''),
          SapLockedField(
              label: 'Codice Fiscale',
              value: c.codiceFiscale ?? avviso.codiceFiscaleCliente ?? ''),
          SapLockedField(label: 'Referente', value: avviso.referente ?? ''),
          SapLockedField(label: 'Telefono', value: c.telefono ?? ''),
          SapLockedField(label: 'Cellulare', value: avviso.cellulare ?? ''),
          SapLockedCheckbox(
              label: 'Contratto Attivo', value: avviso.contrattoAttivo),
          SapLockedField(
              label: 'Codice Contratto',
              value: avviso.codiceContratto ?? avviso.contratto ?? ''),
        ]),
        const SizedBox(height: 8),
        _ContactButtons(c: c, cellulare: avviso.cellulare),
      ],
    );
  }
}

class _ClienteRP extends StatelessWidget {
  final NotificationAvviso avviso;
  const _ClienteRP({required this.avviso});

  @override
  Widget build(BuildContext context) {
    final c = avviso.customer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (c.isBusiness)
          SapLockedField(
              label: 'Ragione Sociale',
              value: c.ragioneSociale ?? '',
              fullWidth: true)
        else
          SapLockedField(label: 'Cliente', value: c.fullName, fullWidth: true),
        const SizedBox(height: 8),
        FormGrid(children: [
          SapLockedField(
              label: 'Codice Cliente',
              value: avviso.codiceCliente ?? c.codCli ?? ''),
          SapLockedField(
              label: 'Codice Fiscale',
              value: c.codiceFiscale ?? avviso.codiceFiscaleCliente ?? ''),
          SapLockedField(label: 'Partita IVA', value: c.partitaIva ?? ''),
          SapLockedField(label: 'Telefono', value: c.telefono ?? ''),
          SapLockedField(
              label: 'Sede Tecnica', value: avviso.sedeTecnica ?? ''),
          SapLockedField(
              label: 'Coordinate GPS',
              value: avviso.address.hasCoordinates
                  ? avviso.address.gpsCoordinates
                  : ''),
        ]),
        const SizedBox(height: 8),
        _ContactButtons(c: c, cellulare: avviso.cellulare),
      ],
    );
  }
}

class _ContactButtons extends StatelessWidget {
  final Customer c;
  final String? cellulare;
  const _ContactButtons({required this.c, this.cellulare});

  @override
  Widget build(BuildContext context) {
    final tel = (c.telefono?.isNotEmpty == true) ? c.telefono : cellulare;
    final hasTel = tel != null && tel.isNotEmpty;
    final hasEmail = (c.email ?? '').isNotEmpty;
    if (!hasTel && !hasEmail) return const SizedBox.shrink();
    return Row(children: [
      if (hasTel)
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => launchUrl(Uri(scheme: 'tel', path: tel)),
            icon: const Icon(Icons.phone_outlined, size: 16),
            label: const Text('Chiama'),
          ),
        ),
      if (hasTel && hasEmail) const SizedBox(width: 8),
      if (hasEmail)
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => launchUrl(Uri(scheme: 'mailto', path: c.email)),
            icon: const Icon(Icons.email_outlined, size: 16),
            label: const Text('Email'),
          ),
        ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════
// INDIRIZZO BLOCCO (generico)
// ════════════════════════════════════════════════════════════════════

class _IndirizzoBlocco extends StatelessWidget {
  final Address address;
  final String? telefonoExtra;
  final String? areaTecnica;
  final bool showGps;
  const _IndirizzoBlocco({
    required this.address,
    this.telefonoExtra,
    this.areaTecnica,
    this.showGps = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormGrid(children: [
          SapLockedField(label: 'Via', value: address.street),
          SapLockedField(label: 'Numero Civico', value: address.streetNumber),
          SapLockedField(label: 'CAP', value: address.cap),
          SapLockedField(label: 'Localita', value: address.localita),
          SapLockedField(label: 'Comune', value: address.city),
          SapLockedField(label: 'Provincia', value: address.provincia),
          if (telefonoExtra != null)
            SapLockedField(label: 'Telefono', value: telefonoExtra!),
          if (areaTecnica != null)
            SapLockedField(label: 'Area Tecnica', value: areaTecnica!),
        ]),
        if (address.additionalInfo.isNotEmpty) ...[
          const SizedBox(height: 6),
          SapLockedField(
              label: 'Informazioni Aggiuntive',
              value: address.additionalInfo,
              fullWidth: true),
        ],
/*         if (showGps && address.hasCoordinates) ...[
          const SizedBox(height: 6),
          SapLockedField(
              label: 'Coordinate GPS',
              value: address.gpsCoordinates,
              fullWidth: true),
        ], */
        if (address.hasCoordinates) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.map),
            icon: const Icon(Icons.map_outlined, size: 20),
            label: const Text('Apri in mappa'),
          ),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// INDIRIZZO OGGETTO PI
// ════════════════════════════════════════════════════════════════════

class _IndirizzoOggettoPI extends StatelessWidget {
  final NotificationAvviso avviso;
  const _IndirizzoOggettoPI({required this.avviso});

  @override
  Widget build(BuildContext context) {
    final addr = avviso.indirizzoOggetto ?? avviso.address;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SapLockedField(
            label: 'Sede Tecnica (SAP)',
            value: avviso.sedeTecnica ?? '',
            fullWidth: true,
            hideIfEmpty: false),
        const SizedBox(height: 6),
        FormGrid(children: [
          SapLockedField(label: 'Via Oggetto', value: addr.street),
          SapLockedField(label: 'Numero Civico', value: addr.streetNumber),
          SapLockedField(label: 'CAP', value: addr.cap),
          SapLockedField(label: 'Localita', value: addr.localita),
          SapLockedField(label: 'Comune', value: addr.city),
          SapLockedField(label: 'Provincia', value: addr.provincia),
          SapLockedField(label: 'Equipment', value: avviso.equipment ?? ''),
          SapLockedField(label: 'Impianto', value: avviso.impianto ?? ''),
          SapLockedField(
              label: 'Punto Misura', value: avviso.puntoMisura ?? ''),
        ]),
        if (addr.additionalInfo.isNotEmpty) ...[
          const SizedBox(height: 6),
          SapLockedField(
              label: 'Informazioni Aggiuntive',
              value: addr.additionalInfo,
              fullWidth: true),
        ],
        if ((avviso.noteAccesso ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          SapLockedField(
              label: 'Note Accesso',
              value: avviso.noteAccesso!,
              fullWidth: true),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// INDIRIZZI RP
// ════════════════════════════════════════════════════════════════════

class _IndirizziRP extends StatelessWidget {
  final NotificationAvviso avviso;
  const _IndirizziRP({required this.avviso});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AddrBlock(
            label: 'INDIRIZZO CLIENTE',
            address: avviso.address,
            telefono: avviso.indirizzoAvvisoTelefono),
        if (avviso.indirizzoOggetto != null) ...[
          const SizedBox(height: 12),
          _AddrBlock(
              label: 'INDIRIZZO OGGETTO', address: avviso.indirizzoOggetto!),
        ],
        if (avviso.indirizzoLavoro != null) ...[
          const SizedBox(height: 12),
          _AddrBlock(
              label: 'INDIRIZZO LAVORO',
              address: avviso.indirizzoLavoro!,
              showGps: true),
        ],
      ],
    );
  }
}

class _AddrBlock extends StatelessWidget {
  final String label;
  final Address address;
  final String? telefono;
  final bool showGps;
  const _AddrBlock({
    required this.label,
    required this.address,
    this.telefono,
    this.showGps = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.6)),
        const SizedBox(height: 6),
        FormGrid(children: [
          SapLockedField(label: 'Via', value: address.street),
          SapLockedField(label: 'Civico', value: address.streetNumber),
          SapLockedField(label: 'CAP', value: address.cap),
          SapLockedField(label: 'Localita', value: address.localita),
          SapLockedField(label: 'Comune', value: address.city),
          SapLockedField(label: 'Provincia', value: address.provincia),
          if (telefono != null)
            SapLockedField(label: 'Telefono', value: telefono!),
        ]),
        if (address.additionalInfo.isNotEmpty) ...[
          const SizedBox(height: 4),
          SapLockedField(
              label: 'Informazioni Aggiuntive',
              value: address.additionalInfo,
              fullWidth: true),
        ],
        /* if (showGps && address.hasCoordinates) ...[
          const SizedBox(height: 4),
          SapLockedField(
              label: 'Coordinate GPS',
              value: address.gpsCoordinates,
              fullWidth: true),
        ], */
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// DATI TECNICI
// ════════════════════════════════════════════════════════════════════

class _DatiTecnici extends StatelessWidget {
  final NotificationAvviso avviso;
  const _DatiTecnici({required this.avviso});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (avviso.statoEquipment != null) ...[
          _EquipmentStatoBadge(stato: avviso.statoEquipment!),
          const SizedBox(height: 8),
        ],
        FormGrid(children: [
          SapLockedField(
              label: 'Sede Tecnica', value: avviso.sedeTecnica ?? ''),
          // Centro di manutenzione SAP (IWERK): valorizzato al 100%.
          SapLockedField(
              label: 'Centro Manutenzione',
              value: avviso.centroManut ?? '',
              hideIfEmpty: true),
          SapLockedField(
              label: 'Ubicazione Tecnica',
              value: avviso.ubicazioneTecnica ?? ''),
          SapLockedField(label: 'Equipment', value: avviso.equipment ?? ''),
          SapLockedField(label: 'Matricola', value: avviso.matricola ?? ''),
          SapLockedField(
              label: 'Stato Equipment',
              value: avviso.statoEquipment?.label ?? ''),
          SapLockedField(
              label: 'Categoria Tecnica', value: avviso.categoriaTecnica ?? ''),
          SapLockedField(
              label: 'Tipo Impianto', value: avviso.tipoImpianto ?? ''),
          SapLockedField(
              label: 'Codice Impianto', value: avviso.impianto ?? ''),
          SapLockedField(
              label: 'Punto Misura', value: avviso.puntoMisura ?? ''),
          SapLockedField(
              label: 'Codice Materiale', value: avviso.codiceMateriale ?? ''),
          SapLockedField(label: 'Calibro', value: avviso.calibro ?? ''),
        ]),
      ],
    );
  }
}

class _EquipmentStatoBadge extends StatelessWidget {
  final StatoEquipment stato;
  const _EquipmentStatoBadge({required this.stato});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: stato.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: stato.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(stato.icon, size: 16, color: stato.color),
          const SizedBox(width: 8),
          Text('Equipment: ${stato.label}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: stato.color)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// GESTIONE INTERVENTO (PI)
// ════════════════════════════════════════════════════════════════════

class _GestioneIntervento extends StatelessWidget {
  final NotificationAvviso avviso;
  const _GestioneIntervento({required this.avviso});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (avviso.statoOperativo != null) ...[
          _StatoOperativoBadge(stato: avviso.statoOperativo!),
          const SizedBox(height: 8),
        ],
        FormGrid(children: [
          SapLockedField(
              label: 'Assegnato A',
              value: avviso.assegnatoA ?? avviso.cidAssegnato ?? ''),
          SapLockedField(label: 'Squadra', value: avviso.squadra ?? ''),
          SapLockedField(
              label: 'Data Intervento',
              value: Fmt.date(avviso.dataInterventoRichiesta)),
          SapLockedField(
              label: 'Fascia Oraria', value: avviso.fasciaOraria?.label ?? ''),
          SapLockedField(
              label: 'Data Inizio Guasto',
              value: Fmt.date(avviso.dataInizioGuasto)),
          SapLockedField(
              label: 'Data Fine Guasto',
              value: Fmt.date(avviso.dataFineGuasto)),
          SapLockedField(
              label: 'Presa in Carico',
              value: Fmt.dateTime(avviso.dataPresaInCarico)),
          SapLockedField(
              label: 'Invio Tecnico',
              value: Fmt.dateTime(avviso.dataInvioTecnico)),
          SapLockedField(
              label: 'Arrivo Previsto',
              value: Fmt.dateTime(avviso.dataArrivoPrevista)),
        ]),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: SapLockedCheckbox(
                    label: 'Intervento Urgente', value: avviso.urgente)),
            const SizedBox(width: 8),
            Expanded(
                child: SapLockedCheckbox(
                    label: 'Reperibilita Attiva', value: avviso.reperibilita)),
          ],
        ),
        if ((avviso.motivoUrgenza ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          SapLockedField(
              label: 'Motivo Urgenza',
              value: avviso.motivoUrgenza!,
              fullWidth: true),
        ],
      ],
    );
  }
}

class _StatoOperativoBadge extends StatelessWidget {
  final StatoOperativo stato;
  const _StatoOperativoBadge({required this.stato});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: stato.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: stato.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(stato.icon, size: 20, color: stato.color),
          const SizedBox(width: 10),
          const Text('Stato Operativo: ', style: AppTextStyles.bodyMedium),
          Text(stato.label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: stato.color)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// DATI PREVENTIVO (RP)
// ════════════════════════════════════════════════════════════════════

/// Sezione "Dati Preventivo" — EDITABILE.
///
/// I campi qui sono dati locali del preventivo (non SAP) e quindi il
/// tecnico può inserirli/modificarli. La persistenza è automatica:
/// ogni modifica aggiorna il Preventivo via [avvisoExtensionProvider].
/// Se il Preventivo non esiste ancora, viene creato come bozza al primo edit.
class _DatiPreventivoRP extends ConsumerStatefulWidget {
  final NotificationAvviso avviso;
  final Preventivo? preventivo;
  const _DatiPreventivoRP({required this.avviso, this.preventivo});

  @override
  ConsumerState<_DatiPreventivoRP> createState() => _DatiPreventivoRPState();
}

class _DatiPreventivoRPState extends ConsumerState<_DatiPreventivoRP> {
  late final TextEditingController _cidCtrl;
  late final TextEditingController _tecnicoCtrl;
  late final TextEditingController _descrCtrl;
  TipoRichiestaPreventivo? _tipo;
  DateTime? _dataSopralluogo;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    final p = widget.preventivo;
    _cidCtrl =
        TextEditingController(text: p?.cidCollegato ?? widget.avviso.cid ?? '');
    _tecnicoCtrl = TextEditingController(text: p?.tecnicoSopralluogo ?? '');
    _descrCtrl =
        TextEditingController(text: p?.descrizioneLavoriRichiesti ?? '');
    _tipo = p?.tipoRichiesta;
    _dataSopralluogo = p?.dataSopralluogo;
    _initialized = true;
  }

  @override
  void didUpdateWidget(covariant _DatiPreventivoRP oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-sync dei controller se il preventivo cambia dall'esterno
    // (es. firma cliente acquisita), ma SOLO se il valore differisce
    // da quanto digitato dall'utente — altrimenti restiamo silenti per
    // non cancellare la sua scrittura.
    final p = widget.preventivo;
    if (p == null || !_initialized) return;
    if (p.tipoRichiesta != _tipo) setState(() => _tipo = p.tipoRichiesta);
    if (p.dataSopralluogo != _dataSopralluogo) {
      setState(() => _dataSopralluogo = p.dataSopralluogo);
    }
  }

  @override
  void dispose() {
    _cidCtrl.dispose();
    _tecnicoCtrl.dispose();
    _descrCtrl.dispose();
    super.dispose();
  }

  /// Restituisce il preventivo corrente o ne crea uno nuovo (bozza).
  Preventivo _ensurePreventivo() =>
      widget.preventivo ?? Preventivo.bozza(widget.avviso.numeroAvviso);

  Future<void> _persist({
    TipoRichiestaPreventivo? tipoRichiesta,
    DateTime? dataSopralluogo,
    bool clearDataSopralluogo = false,
    String? tecnicoSopralluogo,
    String? cidCollegato,
    String? descrizioneLavoriRichiesti,
  }) async {
    final base = _ensurePreventivo();
    final updated = base.copyWith(
      tipoRichiesta: tipoRichiesta ?? base.tipoRichiesta,
      dataSopralluogo: clearDataSopralluogo
          ? null
          : (dataSopralluogo ?? base.dataSopralluogo),
      tecnicoSopralluogo: tecnicoSopralluogo ?? base.tecnicoSopralluogo,
      cidCollegato: cidCollegato ?? base.cidCollegato,
      descrizioneLavoriRichiesti:
          descrizioneLavoriRichiesti ?? base.descrizioneLavoriRichiesti,
    );
    await ref
        .read(avvisoExtensionProvider(widget.avviso.numeroAvviso).notifier)
        .setPreventivo(updated);
  }

  Future<void> _pickDataSopralluogo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataSopralluogo ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() => _dataSopralluogo = picked);
    await _persist(dataSopralluogo: picked);
  }

  @override
  Widget build(BuildContext context) {
    final odlGen = widget.preventivo?.odlGenerato == true ||
        widget.avviso.hasOrdineCollegato;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner highlight tipo richiesta (se selezionato).
        if (_tipo != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(_tipo!.icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('Tipo Richiesta: ', style: AppTextStyles.bodyMedium),
                Expanded(
                  child: Text(_tipo!.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        // Tipo richiesta (dropdown EDITABILE).
        DropdownButtonFormField<TipoRichiestaPreventivo>(
          initialValue: _tipo,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Tipo Richiesta',
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: TipoRichiestaPreventivo.values
              .map((t) => DropdownMenuItem(
                    value: t,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.icon, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(t.label),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: (v) {
            setState(() => _tipo = v);
            if (v != null) _persist(tipoRichiesta: v);
          },
        ),
        const SizedBox(height: 10),
        // Riga 1: CID collegato + Data sopralluogo
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _cidCtrl,
                decoration: const InputDecoration(
                  labelText: 'CID Collegato',
                  prefixIcon: Icon(Icons.tag_rounded),
                ),
                onChanged: (v) => _persist(cidCollegato: v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: _pickDataSopralluogo,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data Sopralluogo',
                    prefixIcon: Icon(Icons.event_outlined),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _dataSopralluogo == null
                              ? 'Seleziona…'
                              : Fmt.date(_dataSopralluogo),
                          style: TextStyle(
                              fontSize: 14,
                              color: _dataSopralluogo == null
                                  ? AppColors.textHint
                                  : AppColors.textPrimary),
                        ),
                      ),
                      if (_dataSopralluogo != null)
                        InkWell(
                          onTap: () {
                            setState(() => _dataSopralluogo = null);
                            _persist(clearDataSopralluogo: true);
                          },
                          child: const Icon(Icons.close,
                              size: 16, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Riga 2: Tecnico sopralluogo + ODL Generato (read-only derivato)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _tecnicoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tecnico Sopralluogo',
                  prefixIcon: Icon(Icons.engineering_outlined),
                ),
                onChanged: (v) => _persist(tecnicoSopralluogo: v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DerivedCheckbox(
                label: 'ODL Generato',
                value: odlGen,
                tooltip: 'Si attiva automaticamente quando viene creato '
                    'un Ordine di Lavoro da questo Avviso.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Descrizione lavori richiesti (TextField multi-line).
        TextField(
          controller: _descrCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Descrizione Lavori Richiesti',
            alignLabelWithHint: true,
            hintText:
                'Descrivi i lavori richiesti dal cliente per il preventivo…',
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: 60),
              child: Icon(Icons.description_outlined),
            ),
          ),
          onChanged: (v) => _persist(descrizioneLavoriRichiesti: v),
        ),
      ],
    );
  }
}

/// Checkbox in sola lettura derivato da uno stato dell'app (non SAP).
/// Mostra un'icona "info" cliccabile con tooltip che spiega quando si attiva.
class _DerivedCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final String tooltip;
  const _DerivedCheckbox({
    required this.label,
    required this.value,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTextStyles.fieldLabel),
          const SizedBox(height: 4),
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: IgnorePointer(
                  child: Checkbox(
                    value: value,
                    onChanged: (_) {},
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeColor: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value ? 'Si' : 'No',
                  style: AppTextStyles.fieldValueReadOnly.copyWith(
                    fontWeight: FontWeight.w600,
                    color: value ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
              Tooltip(
                message: tooltip,
                child: const Icon(Icons.info_outline,
                    size: 14, color: AppColors.textHint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// ELABORAZIONE (campi operatore — editabili inline con la matita)
// ════════════════════════════════════════════════════════════════════

/// Sezione "Elaborazione" — dati operatore (NON SAP), modificabili in place.
///
/// In sola lettura mostra i valori correnti; quando l'operatore preme la
/// matita ([avvisoEditModeProvider] = true) i campi diventano editabili e
/// ogni modifica viene persistita automaticamente in [AvvisoExtension]
/// (stesso pattern auto-save di [_DatiPreventivoRP]). Sostituisce la vecchia
/// pagina "Elabora avviso" full-screen.
class _ElaborazioneSection extends ConsumerStatefulWidget {
  final NotificationAvviso avviso;
  final AvvisoElaborazione? elaborazione;
  const _ElaborazioneSection({required this.avviso, this.elaborazione});

  @override
  ConsumerState<_ElaborazioneSection> createState() =>
      _ElaborazioneSectionState();
}

class _ElaborazioneSectionState extends ConsumerState<_ElaborazioneSection> {
  static const _statiUtente = [
    'I0001 — Iniziato',
    'I0002 — In esecuzione',
    'I0003 — Sospeso',
    'I0005 — Chiuso',
    'I0006 — Annullato',
  ];
  static const _prioritaList = [
    '0 — Altro, no pericolo',
    '1 — Bassa',
    '2 — Media',
    '3 — Alta',
    '4 — Critica',
  ];
  static const _esitoVerList = [
    '-NONE-',
    'OK — Verifica positiva',
    'NO — Verifica negativa',
    'PD — Pendente',
  ];

  late final TextEditingController _sedeTecCtrl;
  late final TextEditingController _equipmentCtrl;
  late final TextEditingController _pressioneCtrl;
  late final TextEditingController _noteCtrl;
  String? _statoUtente;
  String? _priorita;
  String _esito = '-NONE-';
  bool _fermoMacchina = false;

  @override
  void initState() {
    super.initState();
    final e = widget.elaborazione;
    _sedeTecCtrl = TextEditingController(
        text: e?.sedeTecnica ?? widget.avviso.sedeTecnica ?? '');
    _equipmentCtrl = TextEditingController(
        text: e?.equipment ?? widget.avviso.equipment ?? '');
    _pressioneCtrl = TextEditingController(text: e?.pressioneBar ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _statoUtente = e?.statoUtente ??
        _statiUtente.firstWhere((s) => s.contains(widget.avviso.stato),
            orElse: () => _statiUtente.first);
    _priorita = e?.priorita ??
        _prioritaList.firstWhere((p) => p.startsWith(widget.avviso.priorita),
            orElse: () => _prioritaList.first);
    _esito = e?.esitoVer ?? '-NONE-';
    _fermoMacchina = e?.fermoMacchina ?? false;
    // Auto-save su ogni modifica testuale (come _DatiPreventivoRP).
    for (final c in [_sedeTecCtrl, _equipmentCtrl, _pressioneCtrl, _noteCtrl]) {
      c.addListener(_persist);
    }
  }

  @override
  void dispose() {
    _sedeTecCtrl.dispose();
    _equipmentCtrl.dispose();
    _pressioneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _persist() {
    ref
        .read(avvisoExtensionProvider(widget.avviso.numeroAvviso).notifier)
        .setElaborazione(AvvisoElaborazione(
          statoUtente: _statoUtente,
          priorita: _priorita,
          sedeTecnica: _sedeTecCtrl.text,
          equipment: _equipmentCtrl.text,
          fermoMacchina: _fermoMacchina,
          pressioneBar: _pressioneCtrl.text,
          esitoVer: _esito,
          note: _noteCtrl.text,
          updatedAt: DateTime.now(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final editing =
        ref.watch(avvisoEditModeProvider(widget.avviso.numeroAvviso));
    return editing ? _buildEdit() : _buildRead();
  }

  Widget _buildRead() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [
          Icon(Icons.edit_outlined, size: 14, color: AppColors.textHint),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Premi la matita in alto per elaborare questi campi.',
              style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        FormGrid(children: [
          FieldRow(
              label: 'Stato Utente',
              value: _statoUtente ?? '',
              hideIfEmpty: true),
          FieldRow(
              label: 'Priorità', value: _priorita ?? '', hideIfEmpty: true),
          FieldRow(
              label: 'Sede Tecnica',
              value: _sedeTecCtrl.text,
              hideIfEmpty: true),
          FieldRow(
              label: 'Equipment',
              value: _equipmentCtrl.text,
              hideIfEmpty: true),
          FieldRow(
              label: 'Pressione (bar)',
              value: _pressioneCtrl.text,
              hideIfEmpty: true),
          FieldRow(
              label: 'Esito VER',
              value: _esito == '-NONE-' ? '' : _esito,
              hideIfEmpty: true),
          FieldRow(
              label: 'Fermo Macchina', value: _fermoMacchina ? 'Sì' : 'No'),
        ]),
        if (_noteCtrl.text.isNotEmpty) ...[
          const SizedBox(height: 6),
          FieldRow(label: 'Note', value: _noteCtrl.text, fullWidth: true),
        ],
      ],
    );
  }

  Widget _buildEdit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _statoUtente,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Stato utente'),
          items: _statiUtente
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) {
            setState(() => _statoUtente = v);
            _persist();
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _priorita,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Priorità'),
          items: _prioritaList
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (v) {
            setState(() => _priorita = v);
            _persist();
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _sedeTecCtrl,
          decoration: const InputDecoration(labelText: 'Sede tecnica'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _equipmentCtrl,
          decoration: const InputDecoration(labelText: 'Equipment'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Fermo macchina'),
          value: _fermoMacchina,
          onChanged: (v) {
            setState(() => _fermoMacchina = v);
            _persist();
          },
        ),
        const Divider(height: 20),
        const Text('NORMATIVA 655',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.6)),
        const SizedBox(height: 8),
        TextField(
          controller: _pressioneCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
              labelText: 'Pressione (bar)',
              prefixIcon: Icon(Icons.compress_outlined)),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _esito,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Esito VER'),
          items: _esitoVerList
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) {
            setState(() => _esito = v ?? '-NONE-');
            _persist();
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _noteCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
              labelText: 'Note', alignLabelWithHint: true),
        ),
      ],
    );
  }
}
