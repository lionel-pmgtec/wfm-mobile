// Scanner codice a barre / QR con fotocamera reale (mobile_scanner).
// Include: torcia, switch fotocamera (frontale/posteriore), inserimento manuale.
// Ritorna il codice scansionato tramite context.pop(code).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_theme.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  final _manualCtrl = TextEditingController();
  late final MobileScannerController _scanner;
  bool _handled = false;
  bool _torchOn = false;
  bool _showManual = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanner = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
      formats: const [
        BarcodeFormat.qrCode,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.dataMatrix,
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _manualCtrl.dispose();
    _scanner.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scanner.start();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _scanner.stop();
    }
  }

  void _returnCode(String code) {
    if (_handled) return;
    final v = code.trim();
    if (v.isEmpty) return;
    _handled = true;
    context.pop(v);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.firstWhere(
      (b) => (b.rawValue ?? '').isNotEmpty,
      orElse: () => const Barcode(rawValue: null),
    );
    final value = raw.rawValue;
    if (value != null && value.isNotEmpty) _returnCode(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: const BackButton(),
        backgroundColor: Colors.black,
        title: const Text('Scansiona codice'),
        actions: [
          IconButton(
            tooltip: _torchOn ? 'Spegni torcia' : 'Accendi torcia',
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              _scanner.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
          IconButton(
            tooltip: 'Cambia fotocamera',
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: () => _scanner.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _scanner,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) =>
                      _ScannerError(error: error, onRetry: () {
                        _scanner.start();
                        setState(() {});
                      }),
                ),
                // Maschera scura con finestra di scansione al centro
                IgnorePointer(
                  child: CustomPaint(
                    painter: _ScannerOverlayPainter(),
                  ),
                ),
                // Linea di scansione animata
                const Align(
                  alignment: Alignment.center,
                  child: _ScannerLine(),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Text(
                    'Inquadra il QR / barcode dentro la cornice',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      shadows: const [
                        Shadow(blurRadius: 4, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_showManual)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _showManual = true),
                      icon: const Icon(Icons.keyboard_outlined, size: 20),
                      label: const Text('Inserimento manuale'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  else ...[
                    TextField(
                      controller: _manualCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Codice manuale',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check_circle,
                              color: AppColors.primary),
                          onPressed: () => _returnCode(_manualCtrl.text),
                        ),
                      ),
                      onSubmitted: _returnCode,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setState(() => _showManual = false),
                      child: const Text('Torna alla fotocamera'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── OVERLAY MASCHERA ─────────────────────────────────────────────────────────

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cutout = _cutoutRect(size);
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final overlay = Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
      Path()..addRRect(RRect.fromRectAndRadius(cutout, const Radius.circular(16))),
    );
    canvas.drawPath(overlay, paint);
    _drawCorners(canvas, cutout);
  }

  void _drawCorners(Canvas canvas, Rect r) {
    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 26.0;
    // angoli
    canvas.drawLine(r.topLeft, r.topLeft + const Offset(len, 0), paint);
    canvas.drawLine(r.topLeft, r.topLeft + const Offset(0, len), paint);
    canvas.drawLine(r.topRight, r.topRight + const Offset(-len, 0), paint);
    canvas.drawLine(r.topRight, r.topRight + const Offset(0, len), paint);
    canvas.drawLine(r.bottomLeft, r.bottomLeft + const Offset(len, 0), paint);
    canvas.drawLine(r.bottomLeft, r.bottomLeft + const Offset(0, -len), paint);
    canvas.drawLine(r.bottomRight, r.bottomRight + const Offset(-len, 0), paint);
    canvas.drawLine(r.bottomRight, r.bottomRight + const Offset(0, -len), paint);
  }

  static Rect _cutoutRect(Size size) {
    final side = (size.shortestSide * 0.72).clamp(220.0, 360.0);
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: side,
      height: side,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── LINEA DI SCANSIONE ANIMATA ───────────────────────────────────────────────

class _ScannerLine extends StatefulWidget {
  const _ScannerLine();

  @override
  State<_ScannerLine> createState() => _ScannerLineState();
}

class _ScannerLineState extends State<_ScannerLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final side = (c.biggest.shortestSide * 0.72).clamp(220.0, 360.0);
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = Curves.easeInOut.transform(_ctrl.value);
            return SizedBox(
              width: side,
              height: side,
              child: Stack(
                children: [
                  Positioned(
                    left: 8,
                    right: 8,
                    top: 8 + t * (side - 16),
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accent.withValues(alpha: 0),
                            AppColors.accent,
                            AppColors.accent.withValues(alpha: 0),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─── STATO DI ERRORE FOTOCAMERA ───────────────────────────────────────────────

class _ScannerError extends StatelessWidget {
  final MobileScannerException error;
  final VoidCallback onRetry;
  const _ScannerError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isPermission =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPermission ? Icons.no_photography_outlined : Icons.error_outline,
              color: Colors.white70,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              isPermission
                  ? 'Accesso alla fotocamera non consentito'
                  : 'Fotocamera non disponibile',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPermission
                  ? 'Concedi il permesso "Fotocamera" dalle impostazioni di sistema per scansionare i codici QR/barcode.'
                  : 'Verifica che il dispositivo abbia una fotocamera e riprova.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}
