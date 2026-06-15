// Acquisizione firma cliente legata al Preventivo.
//
// Flusso :
//   1. Tecnico inserisce nome firmatario
//   2. Cliente firma sul canvas
//   3. Confermando, la firma viene esportata in PNG (base64) e collegata
//      al Preventivo. Lo stato del Preventivo passa a "firmato".
//
// Geometria : il canvas viene esportato a dimensione fissa 800×400 px per
// avere un PNG coerente nel PDF.

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../domain/entities/entities.dart';
import '../../../providers/avviso_extension_provider.dart';

class PreventivoFirmaScreen extends ConsumerStatefulWidget {
  final String numeroAvviso;
  const PreventivoFirmaScreen({super.key, required this.numeroAvviso});

  @override
  ConsumerState<PreventivoFirmaScreen> createState() =>
      _PreventivoFirmaScreenState();
}

class _PreventivoFirmaScreenState
    extends ConsumerState<PreventivoFirmaScreen> {
  final _nomeCtrl = TextEditingController();
  final List<List<Offset>> _strokes = [];
  final GlobalKey _canvasKey = GlobalKey();
  bool _saving = false;

  bool get _hasSignature => _strokes.any((s) => s.length > 1);
  bool get _canConfirm =>
      _nomeCtrl.text.trim().isNotEmpty && _hasSignature && !_saving;

  void _startStroke(Offset p) => setState(() => _strokes.add([p]));
  void _appendPoint(Offset p) => setState(() => _strokes.last.add(p));
  void _clear() => setState(() => _strokes.clear());

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  Future<Uint8List?> _exportSignaturePng() async {
    final boundary = _canvasKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    final png = await _exportSignaturePng();
    if (png == null) {
      setState(() => _saving = false);
      if (mounted) {
        showSapToast(context, 'Errore esportazione firma', isError: true);
      }
      return;
    }
    final firma = FirmaCliente(
      id: 'FIRMA-${DateTime.now().millisecondsSinceEpoch}',
      nomeFirmatario: _nomeCtrl.text.trim(),
      firmataIl: DateTime.now(),
      pngBase64: base64Encode(png),
    );

    final ext = ref.read(avvisoExtensionProvider(widget.numeroAvviso));
    final prev = ext.preventivo ?? Preventivo.bozza(widget.numeroAvviso);
    final updated = prev.copyWith(
      firma: firma,
      stato: PreventivoStato.firmato,
    );
    await ref
        .read(avvisoExtensionProvider(widget.numeroAvviso).notifier)
        .setPreventivo(updated);

    if (!mounted) return;
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Firma cliente'),
        actions: [
          IconButton(
            tooltip: 'Cancella',
            icon: const Icon(Icons.delete_outline),
            onPressed: _hasSignature ? _clear : null,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: kPagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Inserisci il nome del firmatario e fai firmare il cliente nell\'area sottostante.',
                    style: AppTextStyles.bodyMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _nomeCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome firmatario *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RepaintBoundary(
                key: _canvasKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            onPanStart: (d) => _startStroke(d.localPosition),
                            onPanUpdate: (d) =>
                                _appendPoint(d.localPosition),
                            child: CustomPaint(
                              painter: _SignaturePainter(_strokes),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                        if (!_hasSignature)
                          const Positioned(
                            bottom: 10,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Text(
                                  'Firma qui — il cliente firma toccando lo schermo',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textHint,
                                      fontStyle: FontStyle.italic)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => context.pop(false),
                      child: const Text('Annulla'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _canConfirm ? _confirm : null,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check),
                      label: const Text('Conferma firma'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textPrimary
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      for (var i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) => true;
}
