// Dettaglio Equipment : cerca un equipment per barcode o
// matricola e mostra i dati tecnici (mock).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

class EquipmentDetailScreen extends ConsumerStatefulWidget {
  const EquipmentDetailScreen({super.key});

  @override
  ConsumerState<EquipmentDetailScreen> createState() =>
      _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState
    extends ConsumerState<EquipmentDetailScreen> {
  final _barcodeCtrl = TextEditingController();
  final _matricolaCtrl = TextEditingController();
  String? _produttore;
  String? _localita;
  Equipment? _result;
  bool _searching = false;

  static const _produttori = [
    '-NONE-',
    'MADDALENA',
    'SENSUS',
    'KAMSTRUP',
    'ITRON',
    'ELSTER',
  ];
  static const _localitaOptions = [
    '-NONE-',
    'Centro',
    'Periferia Nord',
    'Periferia Sud',
    'Zona industriale',
  ];

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _matricolaCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await context.push<String>(AppRoutes.scanner);
    if (code != null && code.isNotEmpty) {
      setState(() => _barcodeCtrl.text = code);
    }
  }

  Future<void> _search() async {
    final barcode = _barcodeCtrl.text.trim();
    final matricola = _matricolaCtrl.text.trim();
    if (barcode.isEmpty && matricola.isEmpty) {
      showSapToast(context, 'Inserire barcode o matricola', isError: true);
      return;
    }
    setState(() => _searching = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    // Mock — un equipment fittizio basato sull'input.
    setState(() {
      _searching = false;
      _result = Equipment(
        matricola: matricola.isNotEmpty ? matricola : '15${barcode}A',
        barcode: barcode.isNotEmpty ? barcode : 'BC-${matricola}001',
        produttore: _produttore != null && _produttore != '-NONE-'
            ? _produttore!
            : 'MADDALENA',
        modello: 'MIS. ACQUA 015 5 CIF',
        localita: _localita != null && _localita != '-NONE-'
            ? _localita!
            : 'Centro',
        comune: 'ANCONA',
        sedeTecnica: 'TS-001-ANC',
        dataInstallazione:
            DateTime.now().subtract(const Duration(days: 365 * 4)),
        stato: 'ATTIVO',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dettaglio equipment')),
      body: ListView(
        padding: kPagePadding,
        children: [
          const SectionHeader(title: 'RICERCA'),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _barcodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Barcode',
                  prefixIcon: Icon(Icons.qr_code_outlined),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: _scan,
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scansiona',
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _matricolaCtrl,
            decoration: const InputDecoration(
              labelText: 'Codice matricola',
              prefixIcon: Icon(Icons.numbers_outlined),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _produttore,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Produttore'),
            items: _produttori
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _produttore = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _localita,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Località'),
            items: _localitaOptions
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _localita = v),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _searching ? null : _search,
            icon: _searching
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search),
            label: Text(_searching ? 'Ricerca…' : 'Cerca equipment'),
          ),
          if (_result != null) ...[
            const SectionHeader(title: 'RISULTATO'),
            WfmCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.precision_manufacturing_outlined,
                        color: AppColors.primary, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_result!.displayName,
                              style: AppTextStyles.headingSmall),
                          Text('Matricola: ${_result!.matricola}',
                              style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_result!.stato,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentGreen)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  FormGrid(children: [
                    FieldRow(label: 'Barcode', value: _result!.barcode),
                    FieldRow(label: 'Produttore', value: _result!.produttore),
                    FieldRow(label: 'Modello', value: _result!.modello),
                    FieldRow(label: 'Località', value: _result!.localita),
                    FieldRow(label: 'Comune', value: _result!.comune),
                    FieldRow(
                        label: 'Sede tecnica', value: _result!.sedeTecnica),
                    FieldRow(
                        label: 'Data installazione',
                        value: Fmt.date(_result!.dataInstallazione)),
                  ]),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
