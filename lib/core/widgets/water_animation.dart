// Livello animato di sole goccioline d'acqua per la schermata di login.
// Tutto il codice visivo di questo effetto è isolato qui; nessuna dipendenza esterna.
//
// Utilizzo: aggiungere <WaterAnimationLayer/> in uno Stack (dietro al contenuto).

import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─── PALETTE GOCCIOLINE ──────────────────────────────────────────────────────
const Color _kPipeDark   = Color(0xFF0D47A1); // bordo scuro per profondità
const Color _kDropLight  = Color(0xFF90CAF9); // goccia — azzurro chiaro
const Color _kDropDark   = Color(0xFF1565C0); // goccia — blu scuro

// ─── MODELLI INTERNI ─────────────────────────────────────────────────────────

class _Droplet {
  final double x;       // posizione X normalizzata (0..1)
  final double y0;      // posizione Y di partenza (0..1)
  final double travel;  // distanza di caduta normalizzata (0..1)
  final double size;    // raggio in pixel logici
  final double speed;   // moltiplicatore di velocità
  final double phase;   // sfasamento di fase (0..1)
  final double opacity; // opacità di base

  const _Droplet({
    required this.x,
    required this.y0,
    required this.travel,
    required this.size,
    required this.speed,
    required this.phase,
    required this.opacity,
  });
}

// ─── WIDGET PRINCIPALE ───────────────────────────────────────────────────────

/// Livello a schermo intero da inserire in uno Stack.
/// È trasparente agli eventi tattili (IgnorePointer).
class WaterAnimationLayer extends StatefulWidget {
  const WaterAnimationLayer({super.key});

  @override
  State<WaterAnimationLayer> createState() => _WaterAnimationLayerState();
}

class _WaterAnimationLayerState extends State<WaterAnimationLayer>
    with TickerProviderStateMixin {
  // Controllore principale: pilota la caduta delle gocce (loop 3 s)
  late final AnimationController _fallCtrl;

  // Goccioline pre-calcolate (seme fisso → rendering stabile)
  static final List<_Droplet> _drops = _buildDroplets();

  @override
  void initState() {
    super.initState();
    _fallCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _fallCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _fallCtrl,
        builder: (_, __) => SizedBox.expand(
          child: CustomPaint(
            painter: _WaterPainter(
              fallProgress: _fallCtrl.value,
              drops: _drops,
            ),
          ),
        ),
      ),
    );
  }

  // Genera le gocce una sola volta (seme fisso → aspetto stabile ad ogni hot-reload).
  // Distribuzione uniforme su tutto lo schermo, ora che non ci sono più tubi.
  static List<_Droplet> _buildDroplets() {
    final rng = math.Random(42);
    double r(double lo, double hi) => lo + rng.nextDouble() * (hi - lo);

    return [
      // -- Goccioline grandi (primo piano) -------------------------------------
      for (int i = 0; i < 14; i++)
        _Droplet(
          x: r(0.04, 0.96),
          y0: r(-0.05, 0.40),
          travel: r(0.50, 0.90),
          size: r(7.0, 12.0),
          speed: r(0.5, 1.0),
          phase: r(0.0, 1.0),
          opacity: r(0.70, 1.00),
        ),

      // -- Goccioline medie (livello intermedio) -------------------------------
      for (int i = 0; i < 16; i++)
        _Droplet(
          x: r(0.02, 0.98),
          y0: r(-0.10, 0.50),
          travel: r(0.40, 0.80),
          size: r(4.5, 7.5),
          speed: r(0.7, 1.4),
          phase: r(0.0, 1.0),
          opacity: r(0.50, 0.80),
        ),

      // -- Goccioline piccole (sfondo, scintillanti) ---------------------------
      for (int i = 0; i < 14; i++)
        _Droplet(
          x: r(0.02, 0.98),
          y0: r(-0.10, 0.60),
          travel: r(0.30, 0.70),
          size: r(2.5, 4.5),
          speed: r(1.0, 1.8),
          phase: r(0.0, 1.0),
          opacity: r(0.35, 0.60),
        ),
    ];
  }
}

// ─── PAINTER ─────────────────────────────────────────────────────────────────

class _WaterPainter extends CustomPainter {
  final double fallProgress;  // 0..1, loop
  final List<_Droplet> drops;

  const _WaterPainter({
    required this.fallProgress,
    required this.drops,
  });

  @override
  bool shouldRepaint(_WaterPainter old) => old.fallProgress != fallProgress;

  @override
  void paint(Canvas canvas, Size size) {
    // Impeller crasha se si crea uno shader quando la surface è ancora 0×0
    if (size.isEmpty) return;
    _drawFallingDroplets(canvas, size);
  }

  // ─── GOCCIOLINE IN CADUTA ────────────────────────────────────────────────

  void _drawFallingDroplets(Canvas canvas, Size size) {
    for (final d in drops) {
      // t normalizzato per velocità e fase, riavvolto su [0, 1)
      final t = (fallProgress * d.speed + d.phase) % 1.0;

      final x = d.x * size.width;
      final y = (d.y0 + t * d.travel) * size.height;

      // Dissolvenza in entrata / uscita
      final fadeIn  = (t / 0.12).clamp(0.0, 1.0);
      final fadeOut = ((1.0 - t) / 0.15).clamp(0.0, 1.0);
      final eff = d.opacity * math.min(fadeIn, fadeOut);

      _drawTeardrop(canvas, center: Offset(x, y), radius: d.size, opacity: eff);
    }
  }

  // ─── FORMA A GOCCIA (TEARDROP) ───────────────────────────────────────────

  void _drawTeardrop(Canvas canvas, {
    required Offset center,
    required double radius,
    required double opacity,
  }) {
    if (opacity < 0.02) return;

    final cx = center.dx;
    final cy = center.dy;
    final r  = radius;

    // Punta in alto, ventre arrotondato in basso — due curve di Bézier cubiche
    final path = Path()
      ..moveTo(cx, cy - r * 1.45)
      ..cubicTo(
        cx + r * 1.15, cy - r * 0.30,
        cx + r * 1.00, cy + r * 0.55,
        cx,            cy + r,
      )
      ..cubicTo(
        cx - r * 1.00, cy + r * 0.55,
        cx - r * 1.15, cy - r * 0.30,
        cx,            cy - r * 1.45,
      )
      ..close();

    // Corpo della goccia: gradiente radiale azzurro → blu intenso
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.35),
          radius: 1.0,
          colors: [
            _kDropLight.withValues(alpha: opacity),
            _kDropDark.withValues(alpha: opacity * 0.80),
          ],
        ).createShader(
          Rect.fromCenter(center: center, width: r * 2.6, height: r * 3.0),
        ),
    );

    // Bordo leggermente più scuro per dare profondità
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = _kPipeDark.withValues(alpha: opacity * 0.40),
    );

    // Riflesso: piccola ellisse bianca in alto a sinistra
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - r * 0.28, cy - r * 0.60),
        width:  r * 0.46,
        height: r * 0.62,
      ),
      Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: opacity * 0.75),
    );
  }
}
