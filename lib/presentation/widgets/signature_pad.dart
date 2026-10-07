// Riquadro di firma integrabile in una pagina (non a schermo intero).
//
// Serve alla chiusura dell'intervento: la firma si raccoglie dove si compila
// l'esito, senza cambiare schermata. Il controller espone i tratti, così la
// pagina sa se una firma è stata davvero tracciata.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Stato della firma: tratti disegnati e utilità per leggerli/azzerarli.
class SignaturePadController extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];

  List<List<Offset>> get strokes => List.unmodifiable(_strokes);

  /// Un punto isolato (tocco involontario) non vale come firma.
  bool get hasSignature => _strokes.any((s) => s.length > 1);

  /// Rasterizza la firma in PNG (sfondo bianco), ritagliata sui tratti con un
  /// margine. `null` se non c'è firma. Serve alla chiusura per caricare la
  /// firma come allegato (type FIRMA), non solo il flag `customerSigned`.
  Future<Uint8List?> exportPng({double padding = 16, double strokeWidth = 2.5}) async {
    if (!hasSignature) return null;
    // Riquadro che contiene tutti i punti.
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final s in _strokes) {
      for (final p in s) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
    }
    final w = (maxX - minX) + padding * 2;
    final h = (maxY - minY) + padding * 2;
    if (w <= 0 || h <= 0) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bg = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bg);
    final pen = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final dx = padding - minX;
    final dy = padding - minY;
    for (final stroke in _strokes) {
      if (stroke.length < 2) continue;
      final path = Path()
        ..moveTo(stroke.first.dx + dx, stroke.first.dy + dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx + dx, p.dy + dy);
      }
      canvas.drawPath(path, pen);
    }
    final img =
        await recorder.endRecording().toImage(w.ceil(), h.ceil());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  void startStroke(Offset p) {
    _strokes.add([p]);
    notifyListeners();
  }

  void appendPoint(Offset p) {
    if (_strokes.isEmpty) {
      _strokes.add([p]);
    } else {
      _strokes.last.add(p);
    }
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    notifyListeners();
  }
}

class SignaturePad extends StatelessWidget {
  final SignaturePadController controller;
  final String label;
  final double height;

  const SignaturePad({
    super.key,
    required this.controller,
    this.label = 'Firma',
    this.height = 170,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final firmato = controller.hasSignature;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  firmato ? Icons.check_circle_rounded : Icons.draw_outlined,
                  size: 16,
                  color:
                      firmato ? AppColors.accentGreen : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  firmato ? '$label acquisita' : label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: firmato
                        ? AppColors.accentGreen
                        : AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: firmato ? controller.clear : null,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Cancella'),
                  style: TextButton.styleFrom(
                    // Il tema impone una larghezza minima infinita: qui il
                    // pulsante deve restare compatto dentro la Row.
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: firmato ? AppColors.accentGreen : AppColors.border,
                  width: firmato ? 1.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GestureDetector(
                  onPanStart: (d) => controller.startStroke(d.localPosition),
                  onPanUpdate: (d) => controller.appendPoint(d.localPosition),
                  child: CustomPaint(
                    painter: _SignaturePainter(controller.strokes),
                    child: Center(
                      child: firmato
                          ? const SizedBox.shrink()
                          : const Text(
                              'Firma qui con il dito o con la penna',
                              style: TextStyle(
                                  fontSize: 12.5, color: AppColors.textHint),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  const _SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.textPrimary
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) => true;
}
