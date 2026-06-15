// Anteprima PDF Preventivo con possibilità di condivisione/stampa/email.
//
// Cross-platform :
//   • Web → preview + share/print/download via printing
//   • Mobile → preview + share/print + salvataggio su filesystem +
//     attach come AvvisoDocumento categoria preventivoPdf
//
// Importante : la generazione del PDF e il salvataggio si fanno UNA SOLA
// VOLTA in initState, non dentro al `build:` di PdfPreview (che si chiama
// ad ogni rebuild e crea loop).

import 'dart:io' show File, Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../core/services/preventivo_pdf_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../domain/entities/entities.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/avviso_extension_provider.dart';
import '../../../providers/avvisi_provider.dart';

class PreventivoPdfScreen extends ConsumerStatefulWidget {
  final String numeroAvviso;
  const PreventivoPdfScreen({super.key, required this.numeroAvviso});

  @override
  ConsumerState<PreventivoPdfScreen> createState() =>
      _PreventivoPdfScreenState();
}

class _PreventivoPdfScreenState extends ConsumerState<PreventivoPdfScreen> {
  Uint8List? _bytes;
  String? _error;
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final ext = ref.watch(avvisoExtensionProvider(widget.numeroAvviso));
    final avvisoAsync = ref.watch(avvisoDetailProvider(widget.numeroAvviso));
    final tecnico = ref.watch(authControllerProvider.notifier).user;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Anteprima PDF Preventivo'),
      ),
      body: avvisoAsync.when(
        loading: () => const WfmLoading(),
        error: (e, _) => WfmErrorState(message: e.toString()),
        data: (avviso) {
          final prev = ext.preventivo;
          if (prev == null) {
            return const EmptyState(
              title: 'Nessun preventivo',
              subtitle: 'Crea prima un preventivo con almeno un materiale.',
              icon: Icons.description_outlined,
            );
          }
          if (!prev.hasMateriali) {
            return const EmptyState(
              title: 'Preventivo vuoto',
              subtitle: 'Aggiungi materiali prima di generare il PDF.',
              icon: Icons.inventory_2_outlined,
            );
          }

          // Genera UNA SOLA volta i bytes alla prima build con dati validi.
          if (_bytes == null && _error == null) {
            _generate(avviso, prev, tecnico?.fullName);
            return const Center(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Generazione PDF in corso…'),
              ],
            ));
          }
          if (_error != null) {
            return WfmErrorState(
                message: 'Errore generazione PDF:\n$_error',
                onRetry: () => setState(() {
                      _error = null;
                      _bytes = null;
                    }));
          }

          return Column(
            children: [
              // Barra azioni veloci sopra il preview (più affidabile del viewer su web).
              _ActionBar(
                bytes: _bytes!,
                fileName: _fileName(avviso, prev),
              ),
              Expanded(
                child: PdfPreview(
                  build: (format) async => _bytes!,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  allowSharing: true,
                  allowPrinting: true,
                  pdfFileName: _fileName(avviso, prev),
                  // Su web : nasconde alcuni controlli che possono creare bug
                  useActions: !kIsWeb,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _fileName(NotificationAvviso a, Preventivo p) =>
      '${p.numeroPreventivo.isNotEmpty ? p.numeroPreventivo : p.id}_${a.numeroAvviso}.pdf';

  Future<void> _generate(
      NotificationAvviso avviso, Preventivo prev, String? tecnicoNome) async {
    try {
      final bytes = await PreventivoPdfService.instance.genera(
        avviso: avviso,
        preventivo: prev,
        tecnicoNome: tecnicoNome,
      );
      if (!mounted) return;
      setState(() => _bytes = bytes);
      // Salvataggio fire-and-forget (solo mobile).
      if (!_saved) {
        _saved = true;
        _persistOnDisk(avviso, prev, tecnicoNome);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _persistOnDisk(NotificationAvviso avviso, Preventivo prev,
      String? tecnicoNome) async {
    if (kIsWeb) return; // path_provider non supportato su web
    try {
      final path = await PreventivoPdfService.instance.generaEsalva(
        avviso: avviso,
        preventivo: prev,
        tecnicoNome: tecnicoNome,
      );
      if (path == null || !mounted) return;
      if (prev.pdfPath == path) return;
      final notifier =
          ref.read(avvisoExtensionProvider(widget.numeroAvviso).notifier);
      await notifier.setPreventivo(prev.copyWith(pdfPath: path));
      final stat = await File(path).stat();
      final fileName = path.split(Platform.pathSeparator).last;
      await notifier.addDocumento(AvvisoDocumento(
        id: 'DOC-PDF-${DateTime.now().millisecondsSinceEpoch}',
        categoria: AvvisoDocumentoCategoria.preventivoPdf,
        fileName: fileName,
        filePath: path,
        mimeType: 'application/pdf',
        sizeBytes: stat.size,
        createdAt: DateTime.now(),
      ));
    } catch (_) {
      // Silenzioso : il preview funziona comunque.
    }
  }
}

class _ActionBar extends StatelessWidget {
  final Uint8List bytes;
  final String fileName;
  const _ActionBar({required this.bytes, required this.fileName});

  Future<void> _share() async {
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  Future<void> _print(BuildContext context) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: fileName);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.primarySurface,
        border:
            Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.picture_as_pdf,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('PDF pronto',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                Text(
                    'Scarica, condividi o stampa il preventivo',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Condividi',
            icon: const Icon(Icons.share, color: AppColors.primary),
            onPressed: _share,
          ),
          IconButton(
            tooltip: 'Stampa',
            icon: const Icon(Icons.print, color: AppColors.primary),
            onPressed: () => _print(context),
          ),
        ],
      ),
    );
  }
}
