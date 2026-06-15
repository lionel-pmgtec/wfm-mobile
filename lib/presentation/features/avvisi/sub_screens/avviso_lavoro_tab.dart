// Tab "Lavoro" — consolidamento di:
//   • Azioni workflow: OdL, Preventivo, Firma, PDF, Pagamento
//   • Sospensioni (inline)
//   • Permessi (inline)
//   • Lavori a carico cliente (inline)
//   • Edificio / Impianto (inline)
//   • Note tecniche
//
// Tutto in sezioni repliabili. Niente full-screen push per operazioni
// semplici — solo bottom sheet per l'edit.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../domain/entities/entities.dart';
import '../../../providers/avviso_extension_provider.dart';
import '../widgets/avviso_widgets.dart';

class AvvisoLavoroTab extends ConsumerWidget {
  final NotificationAvviso avviso;
  const AvvisoLavoroTab({super.key, required this.avviso});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = ref.watch(avvisoExtensionProvider(avviso.numeroAvviso));
    return ListView(
      padding: kPagePadding,
      children: [
        // ── Flusso principale (sempre visibile) ──────────────────────────
        WfmCollapsibleSection(
          title: 'FLUSSO',
          icon: Icons.account_tree_outlined,
          child: _FlussoSection(avviso: avviso, ext: ext),
        ),

        // ── Pagamenti registrati ─────────────────────────────────────────
        if (avviso.richiedePreventivo)
          WfmCollapsibleSection(
            title: 'PAGAMENTI',
            icon: Icons.payments_outlined,
            badge: ext.pagamenti.isEmpty
                ? null
                : ext.pagamenti.length.toString(),
            initiallyExpanded: false,
            child: _PagamentiInline(numero: avviso.numeroAvviso, ext: ext),
          ),

        // ── Sospensioni ──────────────────────────────────────────────────
        WfmCollapsibleSection(
          title: 'SOSPENSIONI',
          icon: Icons.pause_circle_outline,
          badge: ext.sospensioni.isEmpty
              ? null
              : ext.sospensioni.length.toString(),
          initiallyExpanded: false,
          child: _SospensioniInline(numero: avviso.numeroAvviso, ext: ext),
        ),

        // ── Permessi ─────────────────────────────────────────────────────
        WfmCollapsibleSection(
          title: 'PERMESSI',
          icon: Icons.verified_outlined,
          badge: ext.permessi.isEmpty ? null : ext.permessi.length.toString(),
          initiallyExpanded: false,
          child: _PermessiInline(numero: avviso.numeroAvviso, ext: ext),
        ),

        // ── Lavori a carico cliente ──────────────────────────────────────
        WfmCollapsibleSection(
          title: 'LAVORI A CARICO CLIENTE',
          icon: Icons.handyman_outlined,
          badge: ext.lavoriCliente.isEmpty
              ? null
              : ext.lavoriCliente.length.toString(),
          initiallyExpanded: false,
          child:
              _LavoriClienteInline(numero: avviso.numeroAvviso, ext: ext),
        ),

        // ── Edificio / Impianto ──────────────────────────────────────────
        WfmCollapsibleSection(
          title: 'EDIFICIO / IMPIANTO',
          icon: Icons.apartment_outlined,
          initiallyExpanded: false,
          child: const _EdificioInline(),
        ),

        // ── Note ─────────────────────────────────────────────────────────
        WfmCollapsibleSection(
          title: 'NOTE TECNICHE',
          icon: Icons.sticky_note_2_outlined,
          badge: ext.note.isEmpty ? null : ext.note.length.toString(),
          initiallyExpanded: false,
          child: _NoteInline(numero: avviso.numeroAvviso, ext: ext),
        ),

        const SizedBox(height: 60),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FLUSSO PRINCIPALE
// ═══════════════════════════════════════════════════════════════════════════

class _FlussoSection extends ConsumerWidget {
  final NotificationAvviso avviso;
  final AvvisoExtension ext;
  const _FlussoSection({required this.avviso, required this.ext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prev = ext.preventivo;
    final stages = <_FlussoStage>[
      // OdL
      _FlussoStage(
        icon: Icons.assignment_outlined,
        title: avviso.hasOrdineCollegato
            ? 'OdL ${avviso.ordineDiLavoro}'
            : 'Ordine di Servizio',
        subtitle: avviso.hasOrdineCollegato
            ? 'Stato: ${avviso.statoOdl ?? '—'}'
            : 'Nessun ordine — genera adesso',
        done: avviso.hasOrdineCollegato,
        ctaLabel: avviso.hasOrdineCollegato ? 'Apri OdL' : 'Genera OdL',
        onCta: () {
          if (avviso.hasOrdineCollegato) {
            context.push(
                AppRoutes.workOrderDetailPath(avviso.ordineDiLavoro!));
          } else {
            context.push(
                AppRoutes.generaOrdineDaAvvisoPath(avviso.numeroAvviso));
          }
        },
      ),
      if (avviso.richiedePreventivo) ...[
        _FlussoStage(
          icon: Icons.description_outlined,
          title: 'Preventivo',
          subtitle: prev == null
              ? 'Crea un nuovo preventivo'
              : '${prev.materiali.length} materiali · '
                  '€ ${prev.totaleConIva.toStringAsFixed(2)} · '
                  '${prev.stato.label}',
          done: prev != null && prev.hasMateriali,
          ctaLabel:
              prev == null || !prev.hasMateriali ? 'Apri' : 'Modifica',
          onCta: () => context.push(
              AppRoutes.preventivoAvvisoPath(avviso.numeroAvviso)),
        ),
        _FlussoStage(
          icon: Icons.draw_outlined,
          title: 'Firma cliente',
          subtitle: prev?.firma != null
              ? '${prev!.firma!.nomeFirmatario} · ${prev.firma!.dataFormattata}'
              : (prev?.hasMateriali == true
                  ? 'Pronta da acquisire'
                  : 'Prima aggiungi i materiali'),
          done: prev?.firma != null,
          ctaLabel: prev?.firma != null ? 'Rifirma' : 'Firma',
          enabled: prev?.hasMateriali == true,
          onCta: () =>
              context.push(AppRoutes.preventivoFirmaPath(avviso.numeroAvviso)),
        ),
        _FlussoStage(
          icon: Icons.picture_as_pdf_outlined,
          title: 'PDF Preventivo',
          subtitle: prev?.hasPdf == true
              ? 'Disponibile · anteprima e condivisione'
              : (prev?.hasMateriali == true
                  ? 'Pronto da generare'
                  : 'Aggiungi prima i materiali'),
          done: prev?.hasPdf == true,
          ctaLabel: prev?.hasPdf == true ? 'Apri' : 'Genera',
          enabled: prev?.hasMateriali == true,
          onCta: () =>
              context.push(AppRoutes.preventivoPdfPath(avviso.numeroAvviso)),
        ),
        // Invio preventivo
        _FlussoStage(
          icon: Icons.send_outlined,
          title: 'Invio preventivo',
          subtitle: prev?.dataInvio != null
              ? 'Inviato il ${Fmt.date(prev!.dataInvio)}'
              : (prev?.hasPdf == true
                  ? 'Pronto da inviare'
                  : 'Prima genera il PDF'),
          done: prev?.dataInvio != null,
          ctaLabel: 'Invia',
          enabled: prev?.hasPdf == true && prev!.stato != PreventivoStato.pagato,
          onCta: () async {
            await ref
                .read(avvisoExtensionProvider(avviso.numeroAvviso).notifier)
                .setPreventivo(prev!.copyWith(
                    stato: PreventivoStato.inviato,
                    dataInvio: DateTime.now()));
            if (context.mounted) {
              showSapToast(context, 'Preventivo contrassegnato inviato');
            }
          },
        ),
        // Approvazione cliente (sostituisce Approva e Rifiuta)
        _FlussoStage(
          icon: prev?.stato == PreventivoStato.rifiutato
              ? Icons.thumb_down_outlined
              : Icons.thumb_up_outlined,
          title: 'Approvazione cliente',
          subtitle: prev?.stato == PreventivoStato.approvato
              ? 'Approvato il ${Fmt.date(prev!.dataApprovazioneCliente)}'
              : prev?.stato == PreventivoStato.rifiutato
                  ? 'Rifiutato${prev!.noteRifiuto != null ? " — ${prev.noteRifiuto}" : ""}'
                  : (prev?.stato == PreventivoStato.inviato
                      ? 'In attesa di risposta cliente'
                      : 'Prima invia il preventivo'),
          done: prev?.stato == PreventivoStato.approvato ||
              prev?.stato == PreventivoStato.pagato ||
              prev?.stato == PreventivoStato.chiuso,
          ctaLabel: prev?.stato == PreventivoStato.approvato ||
                  prev?.stato == PreventivoStato.rifiutato
              ? 'Cambia'
              : 'Esito',
          enabled: prev?.stato == PreventivoStato.inviato ||
              prev?.stato == PreventivoStato.approvato ||
              prev?.stato == PreventivoStato.rifiutato,
          onCta: () async {
            final esito = await _chiediEsitoCliente(context);
            if (esito == null) return;
            await ref
                .read(avvisoExtensionProvider(avviso.numeroAvviso).notifier)
                .setPreventivo(prev!.copyWith(
                  stato: esito.$1,
                  dataApprovazioneCliente: DateTime.now(),
                  noteRifiuto: esito.$2,
                ));
            if (context.mounted) {
              showSapToast(
                  context,
                  esito.$1 == PreventivoStato.approvato
                      ? 'Preventivo approvato dal cliente'
                      : 'Preventivo rifiutato');
            }
          },
        ),
        _FlussoStage(
          icon: Icons.payments_outlined,
          title: 'Pagamento',
          subtitle: prev?.stato == PreventivoStato.pagato ||
                  prev?.stato == PreventivoStato.chiuso
              ? 'Pagato il ${Fmt.date(prev!.dataPagamento)}'
              : (prev?.stato == PreventivoStato.approvato
                  ? 'Pronto da registrare'
                  : 'Serve preventivo approvato'),
          done: prev?.stato == PreventivoStato.pagato ||
              prev?.stato == PreventivoStato.chiuso,
          ctaLabel: 'Registra',
          enabled: prev?.stato == PreventivoStato.approvato,
          onCta: () async {
            final result = await showModalBottomSheet<Pagamento>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _PagamentoSheet(
                  importoDefault: prev!.totaleConIva.toDouble()),
            );
            if (result == null) return;
            final notifier = ref
                .read(avvisoExtensionProvider(avviso.numeroAvviso).notifier);
            await notifier.addPagamento(result);
            // Aggiorna stato preventivo solo se pagamento riuscito
            if (result.esito == EsitoPagamento.riuscito && prev != null) {
              await notifier.setPreventivo(prev.copyWith(
                  stato: PreventivoStato.pagato,
                  dataPagamento: result.dataPagamento));
            }
            if (context.mounted) {
              showSapToast(context,
                  'Pagamento ${result.esito.label.toLowerCase()} registrato');
            }
          },
        ),
      ],
    ];
    return Column(
      children: [
        for (var i = 0; i < stages.length; i++) ...[
          stages[i].build(),
          if (i < stages.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// Dialog : Approva / Rifiuta preventivo lato cliente.
Future<(PreventivoStato, String?)?> _chiediEsitoCliente(
    BuildContext context) async {
  final motivoCtrl = TextEditingController();
  PreventivoStato? scelta;
  return showDialog<(PreventivoStato, String?)>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
      final maxW = MediaQuery.of(ctx).size.width - 40;
      return AlertDialog(
        title: const Text('Esito approvazione cliente'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
              minWidth: maxW.clamp(280.0, 560.0), maxWidth: 560),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RadioListTile<PreventivoStato>(
              value: PreventivoStato.approvato,
              // ignore: deprecated_member_use
              groupValue: scelta,
              // ignore: deprecated_member_use
              onChanged: (v) => setSt(() => scelta = v),
              title: const Text('Approvato'),
              secondary: const Icon(Icons.thumb_up_outlined,
                  color: AppColors.accentGreen),
            ),
            RadioListTile<PreventivoStato>(
              value: PreventivoStato.rifiutato,
              // ignore: deprecated_member_use
              groupValue: scelta,
              // ignore: deprecated_member_use
              onChanged: (v) => setSt(() => scelta = v),
              title: const Text('Rifiutato'),
              secondary: const Icon(Icons.thumb_down_outlined,
                  color: AppColors.accentRed),
            ),
            if (scelta == PreventivoStato.rifiutato) ...[
              const SizedBox(height: 8),
              TextField(
                controller: motivoCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Motivo rifiuto',
                    hintText: 'Es. Prezzo troppo alto'),
              ),
            ],
          ],
        ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla')),
          ElevatedButton(
              onPressed: scelta == null
                  ? null
                  : () => Navigator.pop(
                      ctx,
                      (
                        scelta!,
                        scelta == PreventivoStato.rifiutato
                            ? motivoCtrl.text.trim().isEmpty
                                ? null
                                : motivoCtrl.text.trim()
                            : null
                      )),
              child: const Text('Conferma')),
        ],
      );
    }),
  );
}

/// Bottom sheet : registra un pagamento con importo + metodo + esito.
class _PagamentoSheet extends StatefulWidget {
  final double importoDefault;
  const _PagamentoSheet({required this.importoDefault});
  @override
  State<_PagamentoSheet> createState() => _PagamentoSheetState();
}

class _PagamentoSheetState extends State<_PagamentoSheet> {
  late final TextEditingController _importoCtrl;
  final _riferimentoCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  MetodoPagamento _metodo = MetodoPagamento.contanti;
  EsitoPagamento _esito = EsitoPagamento.riuscito;

  @override
  void initState() {
    super.initState();
    _importoCtrl = TextEditingController(
        text: widget.importoDefault.toStringAsFixed(2).replaceAll('.', ','));
  }

  @override
  void dispose() {
    _importoCtrl.dispose();
    _riferimentoCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final importo =
        num.tryParse(_importoCtrl.text.replaceAll(',', '.')) ?? 0;
    if (importo <= 0) {
      showSapToast(context, 'Importo non valido', isError: true);
      return;
    }
    Navigator.pop(
        context,
        Pagamento(
          id: 'PAG-${DateTime.now().millisecondsSinceEpoch}',
          importo: importo,
          dataPagamento: DateTime.now(),
          metodo: _metodo,
          esito: _esito,
          riferimento: _riferimentoCtrl.text.trim().isEmpty
              ? null
              : _riferimentoCtrl.text.trim(),
          note: _noteCtrl.text.trim(),
          createdAt: DateTime.now(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundPage,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Registra pagamento',
                style: AppTextStyles.headingMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _importoCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Importo *', suffixText: '€'),
            ),
            const SizedBox(height: 10),
            const Text('Metodo di pagamento',
                style: AppTextStyles.fieldLabel),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MetodoPagamento.values
                  .map((m) => ChoiceChip(
                        label: Text(m.label),
                        avatar: Icon(_iconForMetodo(m),
                            size: 16,
                            color: _metodo == m
                                ? Colors.white
                                : AppColors.primary),
                        selected: _metodo == m,
                        onSelected: (_) => setState(() => _metodo = m),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                            color: _metodo == m
                                ? Colors.white
                                : AppColors.primary,
                            fontWeight: FontWeight.w700),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EsitoPagamento>(
              initialValue: _esito,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Esito'),
              items: EsitoPagamento.values
                  .map((e) =>
                      DropdownMenuItem(value: e, child: Text(e.label)))
                  .toList(),
              onChanged: (v) => setState(() => _esito = v ?? _esito),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _riferimentoCtrl,
              decoration: const InputDecoration(
                  labelText: 'Riferimento (ricevuta, IBAN, …)',
                  hintText: 'Opzionale'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Note', alignLabelWithHint: true),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Registra pagamento'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForMetodo(MetodoPagamento m) => switch (m) {
        MetodoPagamento.contanti => Icons.money_outlined,
        MetodoPagamento.carta => Icons.credit_card_outlined,
        MetodoPagamento.bonifico => Icons.account_balance_outlined,
        MetodoPagamento.pos => Icons.point_of_sale_outlined,
      };
}

/// Lista inline dei pagamenti registrati.
class _PagamentiInline extends ConsumerWidget {
  final String numero;
  final AvvisoExtension ext;
  const _PagamentiInline({required this.numero, required this.ext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ext.pagamenti.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text('Nessun pagamento registrato',
            style: TextStyle(
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary)),
      );
    }
    final totale = ext.totalePagato;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in ext.pagamenti)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(children: [
                Icon(_iconMetodo(p.metodo),
                    size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('€ ${p.importo.toStringAsFixed(2)}',
                          style: AppTextStyles.bodyMedium
                              .copyWith(fontWeight: FontWeight.w700)),
                      Text(
                          '${p.metodo.label} · ${Fmt.dateTime(p.dataPagamento)}',
                          style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _colorEsito(p.esito).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(p.esito.label,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _colorEsito(p.esito))),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: AppColors.accentRed),
                  onPressed: () => ref
                      .read(avvisoExtensionProvider(numero).notifier)
                      .removePagamento(p.id),
                ),
              ]),
            ),
          ),
        const Divider(),
        Row(children: [
          const Expanded(
              child: Text('Totale incassato',
                  style: AppTextStyles.bodyMedium)),
          Text('€ ${totale.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentGreen)),
        ]),
      ],
    );
  }

  IconData _iconMetodo(MetodoPagamento m) => switch (m) {
        MetodoPagamento.contanti => Icons.money_outlined,
        MetodoPagamento.carta => Icons.credit_card_outlined,
        MetodoPagamento.bonifico => Icons.account_balance_outlined,
        MetodoPagamento.pos => Icons.point_of_sale_outlined,
      };

  Color _colorEsito(EsitoPagamento e) => switch (e) {
        EsitoPagamento.riuscito => AppColors.accentGreen,
        EsitoPagamento.parziale => AppColors.accentOrange,
        EsitoPagamento.inAttesa => AppColors.primary,
        EsitoPagamento.fallito => AppColors.accentRed,
      };
}

class _FlussoStage {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final String ctaLabel;
  final bool enabled;
  final VoidCallback onCta;
  _FlussoStage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.ctaLabel,
    required this.onCta,
    this.enabled = true,
  });

  Widget build() => Builder(builder: (context) {
        final color = done ? AppColors.accentGreen : AppColors.primary;
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(done ? Icons.check_rounded : icon,
                  color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: AppTextStyles.headingSmall
                          .copyWith(fontSize: 13)),
                  Text(subtitle,
                      style: AppTextStyles.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: enabled ? onCta : null,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 32),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
                child: Text(ctaLabel),
              ),
            ),
          ]),
        );
      });
}

// ═══════════════════════════════════════════════════════════════════════════
// SOSPENSIONI INLINE
// ═══════════════════════════════════════════════════════════════════════════

class _SospensioniInline extends ConsumerWidget {
  final String numero;
  final AvvisoExtension ext;
  const _SospensioniInline({required this.numero, required this.ext});

  Future<void> _addSospensione(BuildContext context, WidgetRef ref) async {
    final res = await showModalBottomSheet<Suspension>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddSospensioneSheet(parentCode: numero),
    );
    if (res != null) {
      await ref
          .read(avvisoExtensionProvider(numero).notifier)
          .addSospensione(res);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ext.sospensioni;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Nessuna sospensione registrata',
                style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary)),
          )
        else
          for (final s in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(
                    s.isActive
                        ? Icons.pause_circle_outline
                        : Icons.check_circle_outline,
                    color: s.isActive
                        ? AppColors.accentOrange
                        : AppColors.accentGreen,
                    size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.type.label,
                          style: AppTextStyles.bodyMedium
                              .copyWith(fontWeight: FontWeight.w600)),
                      Text(Fmt.dateTime(s.startDateTime),
                          style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                if (s.isActive)
                  IconButton(
                    tooltip: 'Chiudi sospensione',
                    icon: const Icon(Icons.check, size: 16),
                    onPressed: () => ref
                        .read(avvisoExtensionProvider(numero).notifier)
                        .closeSospensione(s.id, DateTime.now()),
                  ),
                IconButton(
                  tooltip: 'Elimina',
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: AppColors.accentRed),
                  onPressed: () => ref
                      .read(avvisoExtensionProvider(numero).notifier)
                      .removeSospensione(s.id),
                ),
              ]),
            ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () => _addSospensione(context, ref),
          icon: const Icon(Icons.add_circle_outline, size: 16),
          label: const Text('Aggiungi sospensione'),
        ),
      ],
    );
  }
}

class _AddSospensioneSheet extends StatefulWidget {
  final String parentCode;
  const _AddSospensioneSheet({required this.parentCode});
  @override
  State<_AddSospensioneSheet> createState() => _AddSospensioneSheetState();
}

class _AddSospensioneSheetState extends State<_AddSospensioneSheet> {
  SuspensionType _type = SuspensionType.lavoro;
  final _causaCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _causaCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundPage,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Aggiungi sospensione',
                style: AppTextStyles.headingMedium),
            const SizedBox(height: 12),
            DropdownButtonFormField<SuspensionType>(
              initialValue: _type,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Tipo sospensione *'),
              items: SuspensionType.values
                  .map((t) =>
                      DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _causaCtrl,
              decoration: const InputDecoration(labelText: 'Causa'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Note', alignLabelWithHint: true),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(
                context,
                Suspension(
                  id: 'SOSP-${DateTime.now().millisecondsSinceEpoch}',
                  parentCode: widget.parentCode,
                  type: _type,
                  cause: _causaCtrl.text.trim(),
                  note: _noteCtrl.text.trim(),
                  startDateTime: DateTime.now(),
                ),
              ),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PERMESSI INLINE
// ═══════════════════════════════════════════════════════════════════════════

class _PermessiInline extends ConsumerWidget {
  final String numero;
  final AvvisoExtension ext;
  const _PermessiInline({required this.numero, required this.ext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ext.permessi.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Nessun permesso registrato',
                style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary)),
          )
        else
          for (final p in ext.permessi)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () => _edit(context, ref, p),
                child: Row(children: [
                  Icon(p.stato.icon, size: 18, color: p.stato.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${p.tipo} — ${p.numero}',
                            style: AppTextStyles.bodyMedium
                                .copyWith(fontWeight: FontWeight.w600)),
                        Text(
                            p.dataFine == null
                                ? p.stato.label
                                : 'Scad. ${Fmt.date(p.dataFine)} · ${p.stato.label}',
                            style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Elimina',
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: AppColors.accentRed),
                    onPressed: () => ref
                        .read(avvisoExtensionProvider(numero).notifier)
                        .removePermesso(p.id),
                  ),
                ]),
              ),
            ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () => _edit(context, ref, null),
          icon: const Icon(Icons.add_circle_outline, size: 16),
          label: const Text('Aggiungi permesso'),
        ),
      ],
    );
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, Permesso? existing) async {
    final res = await showModalBottomSheet<Permesso>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PermessoSheet(existing: existing),
    );
    if (res == null) return;
    final notifier = ref.read(avvisoExtensionProvider(numero).notifier);
    if (existing == null) {
      await notifier.addPermesso(res);
    } else {
      await notifier.updatePermesso(res);
    }
  }
}

class _PermessoSheet extends StatefulWidget {
  final Permesso? existing;
  const _PermessoSheet({this.existing});
  @override
  State<_PermessoSheet> createState() => _PermessoSheetState();
}

class _PermessoSheetState extends State<_PermessoSheet> {
  late final TextEditingController _tipoCtrl;
  late final TextEditingController _numeroCtrl;
  late final TextEditingController _noteCtrl;
  DateTime? _dataFine;
  late PermessoStato _stato;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _tipoCtrl = TextEditingController(text: e?.tipo ?? '');
    _numeroCtrl = TextEditingController(text: e?.numero ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _dataFine = e?.dataFine;
    _stato = e?.stato ?? PermessoStato.inAttesa;
  }

  @override
  void dispose() {
    _tipoCtrl.dispose();
    _numeroCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_tipoCtrl.text.trim().isEmpty || _numeroCtrl.text.trim().isEmpty) {
      showSapToast(context, 'Compila tipo e numero', isError: true);
      return;
    }
    final p = (widget.existing ??
            Permesso(
                id: 'PERM-${DateTime.now().millisecondsSinceEpoch}',
                tipo: '',
                numero: '',
                createdAt: DateTime.now()))
        .copyWith(
      tipo: _tipoCtrl.text.trim(),
      numero: _numeroCtrl.text.trim(),
      dataFine: _dataFine,
      stato: _stato,
      note: _noteCtrl.text.trim(),
    );
    Navigator.pop(context, p);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundPage,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'Nuovo permesso' : 'Modifica permesso',
                style: AppTextStyles.headingMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _tipoCtrl,
              decoration: const InputDecoration(
                  labelText: 'Tipo *', hintText: 'Scavo, Voirie, ZTL…'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _numeroCtrl,
              decoration: const InputDecoration(
                  labelText: 'Numero protocollo *'),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dataFine ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (d != null) setState(() => _dataFine = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Scadenza',
                    prefixIcon: Icon(Icons.event_outlined)),
                child: Text(_dataFine == null ? '—' : Fmt.date(_dataFine)),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<PermessoStato>(
              initialValue: _stato,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Stato'),
              items: PermessoStato.values
                  .map((s) =>
                      DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (v) => setState(() => _stato = v ?? _stato),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Note', alignLabelWithHint: true),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LAVORI A CARICO CLIENTE INLINE
// ═══════════════════════════════════════════════════════════════════════════

class _LavoriClienteInline extends ConsumerWidget {
  final String numero;
  final AvvisoExtension ext;
  const _LavoriClienteInline({required this.numero, required this.ext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ext.lavoriCliente.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Nessun lavoro registrato',
                style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary)),
          )
        else
          for (final l in ext.lavoriCliente)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () => _edit(context, ref, l),
                child: Row(children: [
                  Icon(l.stato.icon, size: 18, color: l.stato.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.descrizione,
                            style: AppTextStyles.bodyMedium
                                .copyWith(fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        Text(l.stato.label,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: l.stato.color)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Elimina',
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: AppColors.accentRed),
                    onPressed: () => ref
                        .read(avvisoExtensionProvider(numero).notifier)
                        .removeLavoroCliente(l.id),
                  ),
                ]),
              ),
            ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () => _edit(context, ref, null),
          icon: const Icon(Icons.add_circle_outline, size: 16),
          label: const Text('Aggiungi lavoro'),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref,
      LavoroCliente? existing) async {
    final res = await showModalBottomSheet<LavoroCliente>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LavoroSheet(existing: existing),
    );
    if (res == null) return;
    final notifier = ref.read(avvisoExtensionProvider(numero).notifier);
    if (existing == null) {
      await notifier.addLavoroCliente(res);
    } else {
      await notifier.updateLavoroCliente(res);
    }
  }
}

class _LavoroSheet extends StatefulWidget {
  final LavoroCliente? existing;
  const _LavoroSheet({this.existing});
  @override
  State<_LavoroSheet> createState() => _LavoroSheetState();
}

class _LavoroSheetState extends State<_LavoroSheet> {
  late final TextEditingController _descCtrl;
  late final TextEditingController _noteCtrl;
  late LavoroClienteStato _stato;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _descCtrl = TextEditingController(text: e?.descrizione ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _stato = e?.stato ?? LavoroClienteStato.daFare;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_descCtrl.text.trim().isEmpty) {
      showSapToast(context, 'Inserisci la descrizione', isError: true);
      return;
    }
    final l = (widget.existing ??
            LavoroCliente(
                id: 'LAV-${DateTime.now().millisecondsSinceEpoch}',
                descrizione: '',
                createdAt: DateTime.now()))
        .copyWith(
      descrizione: _descCtrl.text.trim(),
      stato: _stato,
      note: _noteCtrl.text.trim(),
    );
    Navigator.pop(context, l);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundPage,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'Nuovo lavoro' : 'Modifica lavoro',
                style: AppTextStyles.headingMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Descrizione *',
                  hintText: 'Es. Predisporre vano contatore'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<LavoroClienteStato>(
              initialValue: _stato,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Stato'),
              items: LavoroClienteStato.values
                  .map((s) =>
                      DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (v) => setState(() => _stato = v ?? _stato),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Note', alignLabelWithHint: true),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EDIFICIO INLINE (form compatto)
// ═══════════════════════════════════════════════════════════════════════════

class _EdificioInline extends StatefulWidget {
  const _EdificioInline();
  @override
  State<_EdificioInline> createState() => _EdificioInlineState();
}

class _EdificioInlineState extends State<_EdificioInline> {
  String? _statoAcc;
  String? _tipoEdificio;
  final _pressioneCtrl = TextEditingController();
  String? _tipoAllaccio;

  static const _statoAccOptions = [
    '-NONE-',
    'Accessibile',
    'Parzialmente accessibile',
    'Non accessibile',
  ];
  static const _tipoEdificioOptions = [
    '-NONE-',
    'Condominio',
    'Villa monofamiliare',
    'Capannone industriale',
    'Centro commerciale',
    'Ufficio',
  ];
  static const _tipoAllaccioOptions = [
    '-NONE-',
    'Fognatura mista',
    'Fognatura separata',
    'Vasca biologica',
  ];

  @override
  void dispose() {
    _pressioneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _statoAcc,
          isExpanded: true,
          decoration: const InputDecoration(
              labelText: 'Stato di accessibilità', isDense: true),
          items: _statoAccOptions
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _statoAcc = v),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _tipoEdificio,
          isExpanded: true,
          decoration: const InputDecoration(
              labelText: 'Tipo edificio', isDense: true),
          items: _tipoEdificioOptions
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _tipoEdificio = v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _pressioneCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Pressione (bar)',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _tipoAllaccio,
          isExpanded: true,
          decoration: const InputDecoration(
              labelText: 'Tipologia allaccio fognatura', isDense: true),
          items: _tipoAllaccioOptions
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _tipoAllaccio = v),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () =>
              showSapToast(context, 'Dati edificio salvati localmente'),
          icon: const Icon(Icons.save_outlined, size: 16),
          label: const Text('Salva'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NOTE INLINE
// ═══════════════════════════════════════════════════════════════════════════

class _NoteInline extends ConsumerWidget {
  final String numero;
  final AvvisoExtension ext;
  const _NoteInline({required this.numero, required this.ext});

  Future<void> _addNota(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) {
        // Larghezza : su tablet/desktop max 600 ; su mobile prende quasi
        // tutto lo schermo (margine orizzontale di 20 dal theme).
        final maxW = MediaQuery.of(ctx).size.width - 40;
        return AlertDialog(
          title: const Text('Nuova nota'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
                minWidth: maxW.clamp(280.0, 560.0),
                maxWidth: 560),
            child: TextField(
              controller: ctrl,
              maxLines: 5,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Scrivi la nota tecnica…',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('Salva')),
          ],
        );
      },
    );
    if (res == null || res.isEmpty) return;
    await ref.read(avvisoExtensionProvider(numero).notifier).addNota(
          AvvisoNota(
            id: 'NOTA-${DateTime.now().millisecondsSinceEpoch}',
            testo: res,
            autoreCid: '',
            createdAt: DateTime.now(),
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ext.note.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Nessuna nota',
                style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary)),
          )
        else
          for (final n in ext.note)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.testo, style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(
                        child: Text(Fmt.dateTime(n.createdAt),
                            style: AppTextStyles.bodySmall),
                      ),
                      InkWell(
                        onTap: () => ref
                            .read(avvisoExtensionProvider(numero).notifier)
                            .removeNota(n.id),
                        child: const Icon(Icons.delete_outline,
                            size: 16, color: AppColors.accentRed),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () => _addNota(context, ref),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Aggiungi nota'),
        ),
      ],
    );
  }
}
