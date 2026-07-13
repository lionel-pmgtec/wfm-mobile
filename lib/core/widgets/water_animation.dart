// Livello animato di sole goccioline d'acqua per la schermata di login.
// Tutto il codice visivo di questo effetto è isolato qui; nessuna dipendenza esterna.
//
// Utilizzo: aggiungere <WaterAnimationLayer/> in uno Stack (dietro al contenuto).

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// ─── PALETTE GOCCIOLINE ──────────────────────────────────────────────────────
const Color _kPipeDark   = Color(0xFF0D47A1); // bordo scuro per profondità
const Color _kDropLight  = Color(0xFF90CAF9); // goccia — azzurro chiaro
const Color _kDropDark   = Color(0xFF1565C0); // goccia — blu scuro

// Secondi impiegati da una goccia a velocità 1.0 per compiere un ciclo completo
// (dall'alto fuori campo fino a sotto lo schermo). Più alto = caduta più lenta.
const double _kBaseFallSeconds = 9.0;

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
    with SingleTickerProviderStateMixin {
  // Tempo MONOTÒNO (secondi trascorsi). Non si azzera mai: così ogni goccia
  // avanza e si riavvolge in modo continuo, senza il "salto" globale periodico
  // che si aveva con un controller in loop 0→1.
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier<double>(0);

  // Goccioline pre-calcolate (seme fisso → rendering stabile)
  static final List<_Droplet> _drops = _buildDroplets();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _time.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _time,
          builder: (_, __) => SizedBox.expand(
            child: CustomPaint(
              painter: _WaterPainter(
                time: _time.value,
                drops: _drops,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Genera le gocce una sola volta (seme fisso → aspetto stabile ad ogni hot-reload).
  //
  // Caduta CONTINUA: ogni goccia parte SOPRA lo schermo (y0 negativo) e
  // attraversa l'intera altezza fino a uscire in basso (travel > 1). Così le
  // dissolvenze in entrata/uscita avvengono fuori campo e non si percepisce più
  // il "lampeggio" di gocce che appaiono/spariscono a metà schermo.
  static List<_Droplet> _buildDroplets() {
    final rng = math.Random(50);
    double r(double lo, double hi) => lo + rng.nextDouble() * (hi - lo);

    return [
      // -- Goccioline grandi (primo piano) -------------------------------------
      for (int i = 0; i < 14; i++)
        _Droplet(
          x: r(0.04, 0.96),
          y0: r(-0.30, -0.05),
          travel: r(1.15, 1.45),
          size: r(5.0, 8.5),
          speed: r(0.6, 1.0),
          phase: r(0.0, 1.0),
          opacity: r(0.70, 1.00),
        ),

      // -- Goccioline medie (livello intermedio) -------------------------------
      for (int i = 0; i < 18; i++)
        _Droplet(
          x: r(0.02, 0.98),
          y0: r(-0.35, -0.05),
          travel: r(1.15, 1.45),
          size: r(3.6, 4.2),
          speed: r(0.8, 1.3),
          phase: r(0.0, 1.0),
          opacity: r(0.50, 0.80),
        ),

      // -- Goccioline piccole (sfondo, scintillanti) ---------------------------
      for (int i = 0; i < 18; i++)
        _Droplet(
          x: r(0.02, 0.98),
          y0: r(-0.40, -0.05),
          travel: r(1.15, 1.50),
          size: r(1.4, 2.6),
          speed: r(1.0, 1.7),
          phase: r(0.0, 1.0),
          opacity: r(0.35, 0.60),
        ),
    ];
  }
}

// ─── PAINTER ─────────────────────────────────────────────────────────────────

class _WaterPainter extends CustomPainter {
  final double time;          // secondi trascorsi, monotòno
  final List<_Droplet> drops;

  const _WaterPainter({
    required this.time,
    required this.drops,
  });

  @override
  bool shouldRepaint(_WaterPainter old) => old.time != time;

  @override
  void paint(Canvas canvas, Size size) {
    // Impeller crasha se si crea uno shader quando la surface è ancora 0×0
    if (size.isEmpty) return;
    _drawFallingDroplets(canvas, size);
  }

  // ─── GOCCIOLINE IN CADUTA ────────────────────────────────────────────────

  void _drawFallingDroplets(Canvas canvas, Size size) {
    for (final d in drops) {
      // Numero di cicli percorsi finora (cresce senza limiti); il modulo lo
      // riavvolge su [0,1) in modo CONTINUO — nessun salto quando t torna a 0
      // perché `time` non si azzera mai.
      final cycles = time / _kBaseFallSeconds;
      final t = (cycles * d.speed + d.phase) % 1.0;

      final x = d.x * size.width;
      final y = (d.y0 + t * d.travel) * size.height;

      // Dissolvenza in entrata / uscita brevi: avvengono mentre la goccia è
      // ancora fuori campo (sopra o sotto), così l'ingresso in schermo è già a
      // piena opacità e non si percepisce alcun "lampeggio".
      final fadeIn  = (t / 0.05).clamp(0.0, 1.0);
      final fadeOut = ((1.0 - t) / 0.05).clamp(0.0, 1.0);
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

