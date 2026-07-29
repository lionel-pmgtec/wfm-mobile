// PAGINA 1 — Accesso SAP.
// Layout responsive: hero split su tablet (pannello brand + card), stacked su
// smartphone. Sfondo a gradiente + animazione acqua (tema utility idrica).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscurePassword = true;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authControllerProvider.notifier).login(
          _userController.text.trim(),
          _passController.text,
        );
    if (!mounted) return;
    if (ok) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AuthLoading;
    final errorMessage = authState is AuthError ? authState.message : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Sfondo scuro → icone di sistema chiare (status + navigation).
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
      body: Stack(
        children: [
          const _GradientBackground(),
          const WaterAnimationLayer(),
          const _DecorGlow(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                // Layout unico, centrato e impilato: branding sopra, card sotto
                // (limitato in larghezza per non allargarsi troppo su tablet).
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildVivaServiziLogo(),
                          const SizedBox(height: 8),
                          _buildBrandingPanel(),
                          const SizedBox(height: 28),
                          _buildFormCard(isLoading, errorMessage),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ── Logo VIVA SERVIZI (immagine ufficiale) ────────────────────────────────
  Widget _buildVivaServiziLogo() {
    return SizedBox(

      height: 190,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Alone perfettamente circolare (bordi invisibili: alpha→0), come per
          // gli altri elementi grafici della pagina.
          Container(
            width: 400,
            height: 340,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF4FC3F7).withValues(alpha: 0.38),
                  const Color(0xFF4FC3F7).withValues(alpha: 0.0),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
          Image.asset(
            'assets/images/logo.png',
            height: 190,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
  
  // ── Pannello di branding ──────────────────────────────────────────────────
  Widget _buildBrandingPanel() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
      const SizedBox(height: 10),
        Text('Gestione Ordini di Lavoro sul campo',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 25,
                height: 2,
                color: Colors.white.withValues(alpha: 0.72))),
      ],
    );
  }

  // ── Card del form ─────────────────────────────────────────────────────────
  Widget _buildFormCard(bool isLoading, String? errorMessage) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 40,
              offset: const Offset(0, 16)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Bentornato',
                      style: TextStyle(
                          fontSize: 35,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 10),
                  const Text('Inserisci le credenziali per accedere',
                      style: TextStyle(
                          fontSize: 20, color: AppColors.textSecondary)),
                  const SizedBox(height: 28),
                  _label('Utente (CID)'),
                  const SizedBox(height: 7),
                  TextFormField(
                    key: const Key('login_username'),
                    controller: _userController,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'es. VAIOTTIM',
                      prefixIcon: Icon(Icons.person_outline,
                          color: AppColors.textHint, size: 30),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Campo obbligatorio'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  _label('Password'),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('login_password'),
                    controller: _passController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: AppColors.textHint, size: 30),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword ? 'Mostra' : 'Nascondi',
                        icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textHint,
                            size: 30),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Campo obbligatorio' : null,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: errorMessage == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _errorBanner(errorMessage),
                          ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      key: const Key('login_submit'),
                      onPressed: isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Accedi',
                                    style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3)),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
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

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.accentRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.accentRed))),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.3));
}

// ─── Sfondo a gradiente ───────────────────────────────────────────────────
class _GradientBackground extends StatelessWidget {
  const _GradientBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
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
      child: SizedBox.expand(),
    );
  }
}

// ─── Aloni decorativi ──────────────────────────────────────────────────────
class _DecorGlow extends StatelessWidget {
  const _DecorGlow();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -w * 0.25,
            right: -w * 0.15,
            child: _circle(w * 0.6, const Color(0xFF4FC3F7), 0.14),
          ),
          Positioned(
            bottom: -w * 0.2,
            left: -w * 0.18,
            child: _circle(w * 0.55, Colors.white, 0.05),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, Color color, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
        ),
      );
}
