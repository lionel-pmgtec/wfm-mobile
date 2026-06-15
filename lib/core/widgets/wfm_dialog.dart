// Sistema di dialog brandizzato WFM (conferma, info, distruttivo).
// Sostituisce AlertDialog di default per dare un look coerente con il
// design system: icona colorata in cerchio, titolo, descrizione, due
// pulsanti grandi (annulla / conferma).

import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

/// Tipo semantico del dialog: cambia colore accento e icona di default.
enum WfmDialogTone { neutral, primary, success, warning, danger }

class _ToneStyle {
  final Color accent;
  final Color surface;
  final IconData icon;
  const _ToneStyle(this.accent, this.surface, this.icon);
}

_ToneStyle _styleFor(WfmDialogTone tone) {
  switch (tone) {
    case WfmDialogTone.success:
      return const _ToneStyle(
          AppColors.accentGreen, Color(0xFFE8F5E9), Icons.check_circle_outline);
    case WfmDialogTone.warning:
      return const _ToneStyle(
          AppColors.accentOrange, Color(0xFFFFF3E0), Icons.warning_amber_rounded);
    case WfmDialogTone.danger:
      return const _ToneStyle(
          AppColors.accentRed, Color(0xFFFDECEC), Icons.error_outline);
    case WfmDialogTone.primary:
      return const _ToneStyle(
          AppColors.primary, AppColors.primarySurface, Icons.info_outline);
    case WfmDialogTone.neutral:
      return const _ToneStyle(
          AppColors.textSecondary, Color(0xFFF1F4F8), Icons.help_outline);
  }
}

/// Mostra un dialog di conferma brandizzato.
/// Ritorna `true` se l'utente conferma, `false`/`null` altrimenti.
Future<bool?> showWfmConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Conferma',
  String cancelLabel = 'Annulla',
  WfmDialogTone tone = WfmDialogTone.primary,
  IconData? icon,
  Widget? extraContent,
}) {
  final style = _styleFor(tone);
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => _WfmDialog(
      title: title,
      message: message,
      icon: icon ?? style.icon,
      accent: style.accent,
      surface: style.surface,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: tone == WfmDialogTone.danger,
      extraContent: extraContent,
    ),
  );
}

/// Variante senza pulsante di annullamento (solo OK).
Future<void> showWfmInfoDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'OK',
  WfmDialogTone tone = WfmDialogTone.primary,
  IconData? icon,
}) async {
  final style = _styleFor(tone);
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => _WfmDialog(
      title: title,
      message: message,
      icon: icon ?? style.icon,
      accent: style.accent,
      surface: style.surface,
      confirmLabel: confirmLabel,
      cancelLabel: null,
      destructive: false,
    ),
  );
}

class _WfmDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color accent;
  final Color surface;
  final String confirmLabel;
  final String? cancelLabel;
  final bool destructive;
  final Widget? extraContent;

  const _WfmDialog({
    required this.title,
    required this.message,
    required this.icon,
    required this.accent,
    required this.surface,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    this.extraContent,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusLg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withValues(alpha: 0.25), width: 1),
                  ),
                  child: Icon(icon, color: accent, size: 32),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.headingMedium,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
              if (extraContent != null) ...[
                const SizedBox(height: 14),
                extraContent!,
              ],
              const SizedBox(height: 22),
              if (cancelLabel == null)
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(confirmLabel),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          side: const BorderSide(color: AppColors.border, width: 1.4),
                          foregroundColor: AppColors.textSecondary,
                        ),
                        child: Text(cancelLabel!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          elevation: destructive ? 0 : 1,
                        ),
                        child: Text(confirmLabel),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
