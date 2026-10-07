import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/notification_avviso.dart';
import '../../../domain/entities/work_order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/avvisi_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/creation_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/work_orders_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider.notifier).user;
    final stats = ref.watch(dashboardStatsProvider);
    final online = ref.watch(connectivityStatusProvider);
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    // Nessun endpoint mobile attuale restituisce l'elenco degli oggetti senza
    // assegnatario: non riutilizzare il conteggio della coda di sincronizzazione.
    const unassignedCount = 0;
    final unreadNotifs = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: kSpacingLg,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              child: Text(user?.initials ?? 'WF',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(user?.fullName ?? 'Tecnico',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  Text(user?.workCenter ?? 'WFM Mobile',
                      style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifiche',
            icon: Badge(
              isLabelVisible: unreadNotifs > 0,
              label: Text('$unreadNotifs'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
            onPressed: () => context.push(AppRoutes.notifications),
          ),
          IconButton(
            tooltip: 'Esci',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardStatsProvider),
        child: ListView(
          padding: kPagePadding,
          children: [
            if (!online || pending > 0) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: WfmOfflineBadge(offline: !online, pendingCount: pending),
              ),
              const SizedBox(height: kSpacingMd),
            ],
            _WelcomeHeader(
              greeting: _greeting(),
              name: (user?.nome ?? '').trim().isEmpty
                  ? 'Tecnico'
                  : (user?.nome ?? '').trim(),
              lines: _headerLines(
                stats.valueOrNull,
                (ref.watch(prontoInterventoWorkOrdersProvider).valueOrNull
                            ?.length ??
                        0) +
                    (ref.watch(prontoInterventoAvvisiProvider).valueOrNull
                            ?.length ??
                        0),
              ),
            ),
            const SizedBox(height: kSpacingLg),
            // Banner PI anche per gli AVVISI (es. ZH), così l'operatore li vede
            // sulla Home senza entrare in Avvisi.
            const _ProntoInterventoAvvisiBanner(),
            // Banner interventi urgenti: visibile subito, sopra il riepilogo.
            // Si auto-nasconde quando non ci sono Pronto Intervento aperti.
            const _ProntoInterventoBanner(),
            const Text('Riepilogo', style: AppTextStyles.headingMedium),
            const SizedBox(height: kSpacingMd),
            stats.when(
              loading: () => const SizedBox(
                  height: 88, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => WfmErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(dashboardStatsProvider)),
              data: (m) => _statsGrid(context, m, unassignedCount),
            ),
            const SizedBox(height: kSpacingXl),
            const Text('Accessi rapidi', style: AppTextStyles.headingMedium),
            const SizedBox(height: kSpacingMd),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: kSpacingMd,
              crossAxisSpacing: kSpacingMd,
              childAspectRatio: 1.05,
              children: [
                _quickAction(context,
                    icon: Icons.add_task_rounded,
                    label: 'Crea OdL',
                    onTap: () => context.push(AppRoutes.createOrder)),
                _quickAction(context,
                    icon: Icons.notification_add_outlined,
                    label: 'Crea avviso',
                    onTap: () => context.push(AppRoutes.createAvviso)),
                _quickAction(context,
                    icon: Icons.widgets_outlined,
                    label: 'Standalone',
                    onTap: () => context.push(AppRoutes.standalone)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Saluto in base all'ora del dispositivo.
  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buongiorno';
    if (h < 18) return 'Buon pomeriggio';
    return 'Buonasera';
  }

  /// Riga di sintesi sotto il saluto, ricavata dai contatori.
  /// Righe che scorrono sotto il saluto (in esecuzione, pronto intervento,
  /// assegnati, chiusi…). Solo le voci con conteggio > 0; niente = riga neutra.
  List<String> _headerLines(Map<WorkOrderStatus, int>? m, int piCount) {
    if (m == null) return const ['Ecco la tua giornata'];
    final inEsec = m[WorkOrderStatus.inEsecuzione] ?? 0;
    final assegnati = m[WorkOrderStatus.ricevuto] ?? 0;
    final pausa = m[WorkOrderStatus.inPausa] ?? 0;
    final sospeso = m[WorkOrderStatus.sospeso] ?? 0;
    final chiuso = m[WorkOrderStatus.completato] ?? 0;
    final lines = <String>[
      if (piCount > 0) '🚨 $piCount pronto intervento',
      if (inEsec > 0) '$inEsec ${inEsec == 1 ? 'ordine' : 'ordini'} in esecuzione',
      if (assegnati > 0) '$assegnati assegnat${assegnati == 1 ? 'o' : 'i'}',
      if (pausa > 0) '$pausa in pausa',
      if (sospeso > 0) '$sospeso sospes${sospeso == 1 ? 'o' : 'i'}',
      if (chiuso > 0) '$chiuso chius${chiuso == 1 ? 'o' : 'i'} oggi',
    ];
    if (lines.isEmpty) lines.add('Nessun ordine assegnato');
    return lines;
  }

  Widget _statsGrid(
      BuildContext context, Map<WorkOrderStatus, int> m, int unassignedCount) {
    final items = [
      (WorkOrderStatus.ricevuto, Icons.inbox_rounded),
      (WorkOrderStatus.inEsecuzione, Icons.play_arrow_rounded),
      (WorkOrderStatus.inPausa, Icons.pause_rounded),
      (WorkOrderStatus.sospeso, Icons.stop_rounded),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: kSpacingSm,
      crossAxisSpacing: kSpacingSm,
      childAspectRatio: 1.5,
      children: items.map<Widget>((e) {
        final style = getStatusStyle(e.$1.label);
        final count = m[e.$1] ?? 0;
        final active = count > 0;
        // Sospeso/Chiuso/Inviato SAP: l'OdL esce dal tablet non appena
        // raggiunge uno di questi stati (non serve più all'operatore, resta
        // sul cruscotto). Il conteggio (dal backend) resta per informazione,
        // ma non si apre più una lista — sarebbe sempre vuota.
        final apribile = e.$1 != WorkOrderStatus.sospeso;
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: apribile
                ? () => context
                    .push(AppRoutes.workOrdersByStatusPath(e.$1.name))
                : null,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: active ? style.background : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active
                      ? style.color.withValues(alpha: 0.35)
                      : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: active ? style.color : style.background,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(e.$2,
                        size: 16,
                        color: active ? Colors.white : style.color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$count',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                height: 1,
                                color: active
                                    ? style.color
                                    : AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(e.$1.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList()
        ..add(_daAssegnareTile(context, unassignedCount)),
    );
  }

  Widget _daAssegnareTile(BuildContext context, int count) {
    final style = getStatusStyle('Da assegnare');
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // L'elenco affidabile degli oggetti non assegnati non è ancora esposto
        // dall'API mobile; non aprire la coda di sincronizzazione al suo posto.
        onTap: null,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: count > 0 ? style.background : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: count > 0
                  ? style.color.withValues(alpha: 0.35)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: count > 0 ? style.color : style.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.assignment_late_outlined,
                    size: 16,
                    color: count > 0 ? Colors.white : style.color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$count',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1,
                            color: count > 0
                                ? style.color
                                : AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    const Text('Da assegnare',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickAction(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap,
      int badge = 0}) {
    return WfmCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: kSpacingMd, horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Badge(
            isLabelVisible: badge > 0,
            label: Text('$badge'),
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
          ),
          const SizedBox(height: 8),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelLarge,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showWfmConfirmDialog(
      context: context,
      title: 'Disconnessione',
      message:
          'Vuoi uscire dall\'applicazione? Le modifiche non sincronizzate resteranno in coda.',
      confirmLabel: 'Esci',
      cancelLabel: 'Annulla',
      tone: WfmDialogTone.danger,
      icon: Icons.logout_rounded,
    );
    if (ok == true && context.mounted) {
      await ref.read(authControllerProvider.notifier).logout();
      if (context.mounted) context.go(AppRoutes.login);
    }
  }
}

/// Banner "Pronto Intervento": bottone rosso molto visibile per gli interventi
/// urgenti, sopra il riepilogo. Mostra i dati del PI più urgente (nome, codice,
/// priorità, tipo) e apre subito il dettaglio (uno solo) o la lista (più d'uno).
/// Si nasconde da sé quando non ci sono Pronto Intervento aperti.
/// Fa "lampeggiare" il contenuto (pulsazione di opacità) per rendere i Pronto
/// Intervento impossibili da ignorare finché non vengono presi in carico.
class _PulseBanner extends StatefulWidget {
  final Widget child;
  const _PulseBanner({required this.child});

  @override
  State<_PulseBanner> createState() => _PulseBannerState();
}

class _PulseBannerState extends State<_PulseBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFE53935);
    // SOLO il colore della cornice pulsa; la LARGHEZZA resta FISSA. Animare la
    // larghezza cambiava la dimensione del banner ad ogni frame => il ListView
    // si ridisponeva e SEMBRAVA che tutta la pagina lampeggiasse. Con
    // foregroundDecoration + larghezza fissa, lampeggia solo il bordo del
    // banner, senza spostare nulla intorno.
    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (context, child) {
        final t = _ctrl.value; // 0..1
        return Container(
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: red.withValues(alpha: 0.10 + 0.90 * t),
              width: 3,
            ),
          ),
          child: child,
        );
      },
    );
  }
}

class _ProntoInterventoBanner extends ConsumerWidget {
  const _ProntoInterventoBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders =
        ref.watch(prontoInterventoWorkOrdersProvider).valueOrNull ??
            const <WorkOrder>[];
    if (orders.isEmpty) return const SizedBox.shrink();

    final primary = orders.first;
    final extra = orders.length - 1;
    void onTap() => orders.length == 1
        ? context.push(AppRoutes.workOrderDetailPath(primary.externalCode))
        : context.push(AppRoutes.prontoIntervento);

    return Padding(
      padding: const EdgeInsets.only(bottom: kSpacingMd),
      child: _PulseBanner(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                ),
              ),
              child: Row(children: [
                const Icon(Icons.flash_on_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        const Text('PRONTO INTERVENTO',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: Colors.white)),
                        if (extra > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('+$extra',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFD32F2F))),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 1),
                      Text(
                        '${primary.displayName} · #${primary.externalCode}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Avvia',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFD32F2F))),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded,
                        size: 14, color: Color(0xFFD32F2F)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner "Pronto Intervento" per gli AVVISI (es. ZH): compatto, sotto quello
/// degli OdL. Permette all'operatore di vedere un PI avviso dalla Home senza
/// aprire la sezione Avvisi.
class _ProntoInterventoAvvisiBanner extends ConsumerWidget {
  const _ProntoInterventoAvvisiBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avvisi = ref.watch(prontoInterventoAvvisiProvider).valueOrNull ??
        const <NotificationAvviso>[];
    if (avvisi.isEmpty) return const SizedBox.shrink();

    final primary = avvisi.first;
    final extra = avvisi.length - 1;
    final titolo = primary.descrizione.trim().isEmpty
        ? 'Pronto Intervento'
        : primary.descrizione.trim();

    void onTap() => avvisi.length == 1
        ? context.push(AppRoutes.avvisoDetailPath(primary.numeroAvviso))
        : context.push(AppRoutes.avvisi);

    const red = Color(0xFFD32F2F);
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpacingMd),
      child: _PulseBanner(
        child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: red.withValues(alpha: 0.5)),
              color: red.withValues(alpha: 0.08),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: red, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PRONTO INTERVENTO · AVVISO',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: red)),
                    const SizedBox(height: 2),
                    Text(titolo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      extra > 0
                          ? '${primary.numeroAvviso} · +$extra altri urgenti'
                          : primary.numeroAvviso,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: red),
            ]),
          ),
        ),
      ),
      ),
    );
  }
}

/// Intestazione di benvenuto con gradiente: saluto + nome + sintesi giornata.
class _WelcomeHeader extends StatefulWidget {
  final String greeting;
  final String name;
  final List<String> lines;
  const _WelcomeHeader({
    required this.greeting,
    required this.name,
    required this.lines,
  });

  @override
  State<_WelcomeHeader> createState() => _WelcomeHeaderState();
}

class _WelcomeHeaderState extends State<_WelcomeHeader> {
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startRotation();
  }

  void _startRotation() {
    _timer?.cancel();
    if (widget.lines.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!mounted) return;
        setState(() => _i = (_i + 1) % widget.lines.length);
      });
    }
  }

  @override
  void didUpdateWidget(covariant _WelcomeHeader old) {
    super.didUpdateWidget(old);
    // La lista è cambiata (nuovi conteggi): riparti dall'inizio.
    if (old.lines.length != widget.lines.length) {
      _i = 0;
      _startRotation();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line =
        widget.lines.isEmpty ? '' : widget.lines[_i % widget.lines.length];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            Color.lerp(AppColors.primary, Colors.black, 0.28)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${widget.greeting}, ${widget.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 4),
                // Sottotitolo che SCORRE fra le voci della giornata.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, anim) => SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.5), end: Offset.zero)
                        .animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Text(line,
                      key: ValueKey(line),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.white70)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.waving_hand_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}
