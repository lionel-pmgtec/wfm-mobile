// Schermata di avvio (splash): mostrata per ~6 secondi prima del login.
// Stesso linguaggio grafico della pagina di accesso (gradiente + logo VIVA),
// con una barra di avanzamento. Alla fine instrada verso il login (o la home
// se la sessione è già attiva); il redirect del router corregge comunque.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/core_providers.dart';

/// Durata dello splash prima di aprire il login.
const Duration kSplashDuration = Duration(seconds: 6);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Un solo controller per: dissolvenza del logo + barra di avanzamento.
    _ctrl = AnimationController(vsync: this, duration: kSplashDuration)
      ..forward();
    _timer = Timer(kSplashDuration, _go);
  }

  void _go() {
    if (!mounted) return;
    final loggedIn = ref.read(authRepositoryProvider).currentUser != null;
    context.go(loggedIn ? AppRoutes.home : AppRoutes.login);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryDark,
                AppColors.primary,
                Color(0xFF2E6BA8),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  FadeTransition(
                    opacity: CurvedAnimation(
                        parent: _ctrl, curve: const Interval(0.0, 0.35)),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 320,
                          height: 280,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF4FC3F7).withValues(alpha: 0.32),
                                const Color(0xFF4FC3F7).withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                        Image.asset('assets/images/logo.png',
                            height: 160, fit: BoxFit.contain),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gestione Ordini di Lavoro sul campo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  // Barra di avanzamento sincronizzata con i 6 secondi.
                  SizedBox(
                    width: 200,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: AnimatedBuilder(
                        animation: _ctrl,
                        builder: (_, __) => LinearProgressIndicator(
                          value: _ctrl.value,
                          minHeight: 4,
                          backgroundColor: Colors.white24,
                          valueColor:
                              const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Caricamento in corso…',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
