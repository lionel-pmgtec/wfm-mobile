// Dettaglio Avviso semplificato — solo 3 tab :
//   • INFO     : dati SAP read-only (collassabili)
//   • LAVORO   : flusso + sospensioni + permessi + lavori cliente
//                + edificio + note (tutto inline)
//   • ALLEGATI : documenti categorizzati (inline)
//
// Niente full-screen push per le liste semplici: tutto in bottom sheet.
// Le uniche schermate stand-alone restano Preventivo / Firma / PDF
// (complessità giustificata).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/avvisi_provider.dart';
import 'sub_screens/avviso_allegati_tab.dart';
import 'sub_screens/avviso_dati_tab.dart';
import 'sub_screens/avviso_lavoro_tab.dart';

class AvvisoDetailScreen extends ConsumerStatefulWidget {
  final String numero;
  const AvvisoDetailScreen({super.key, required this.numero});

  @override
  ConsumerState<AvvisoDetailScreen> createState() =>
      _AvvisoDetailScreenState();
}

class _AvvisoDetailScreenState extends ConsumerState<AvvisoDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(avvisoDetailProvider(widget.numero));
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: Text('Avviso ${widget.numero}'),
        ),
        body: const WfmLoading(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: Text('Avviso ${widget.numero}'),
        ),
        body: WfmErrorState(message: e.toString()),
      ),
      data: (a) => _buildScaffold(a),
    );
  }

  Widget _buildScaffold(NotificationAvviso a) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Avviso ${a.numeroAvviso}',
                style: const TextStyle(fontSize: 16)),
            Text(
              a.sottotipo.label,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Elabora',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                context.push(AppRoutes.elaboraAvvisoPath(widget.numero)),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          dividerColor: Colors.white24,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: 'Info'),
            Tab(icon: Icon(Icons.work_outline), text: 'Lavoro'),
            Tab(icon: Icon(Icons.folder_outlined), text: 'Allegati'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          AvvisoDatiTab(avviso: a),
          AvvisoLavoroTab(avviso: a),
          AvvisoAllegatiTab(numeroAvviso: widget.numero),
        ],
      ),
    );
  }
}
