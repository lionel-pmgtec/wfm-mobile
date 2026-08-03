// Riquadro di firma integrabile in una pagina (non a schermo intero).
//
// Serve alla chiusura dell'intervento: la firma si raccoglie dove si compila
// l'esito, senza cambiare schermata. Il controller espone i tratti, così la
// pagina sa se una firma è stata davvero tracciata.

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Stato della firma: tratti disegnati e utilità per leggerli/azzerarli.
class SignaturePadController extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];

  List<List<Offset>> get strokes => List.unmodifiable(_strokes);

  /// Un punto isolato (tocco involontario) non vale come firma.
  bool get hasSignature => _strokes.any((s) => s.length > 1);

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
