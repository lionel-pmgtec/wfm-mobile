// Componenti UI riutilizzabili aggiuntivi (Design System WFM, specifiche §10.3).

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';
import '../../domain/entities/enums.dart';

// ─── BADGE DI STATO (tipizzato su WorkOrderStatus) ─────────────────────────────

class WoStatusBadge extends StatelessWidget {
  final WorkOrderStatus status;
  final bool small;
  const WoStatusBadge({super.key, required this.status, this.small = false});

  @override
  Widget build(BuildContext context) {
    final style = getStatusStyle(status.label);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 8 : 10, vertical: small ? 3 : 4),
      decoration: BoxDecoration(
          color: style.background, borderRadius: BorderRadius.circular(20)),
      child: Text(style.label,
          style: TextStyle(
              fontSize: small ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: style.color,
              letterSpacing: 0.2)),
    );
  }
}

// ─── BADGE MODALITÀ OFFLINE ───────────────────────────────────────────────────

class WfmOfflineBadge extends StatelessWidget {
  final bool offline;
  final int pendingCount;

  const WfmOfflineBadge({super.key, required this.offline, this.pendingCount = 0});

  @override
  Widget build(BuildContext context) {
    if (!offline && pendingCount == 0) return const SizedBox.shrink();
    final color = offline ? AppColors.accentOrange : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(offline ? Icons.cloud_off_rounded : Icons.sync_rounded,
              size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            offline
                ? 'Offline${pendingCount > 0 ? ' · $pendingCount' : ''}'
                : '$pendingCount in coda',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

// ─── PULSANTE AZIONE PRINCIPALE (Avvia / Sospendi / Concludi) ──────────────────

class WfmActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool expanded;

  const WfmActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final btn = ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.border,
        minimumSize: const Size.fromHeight(kPrimaryButtonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusMd)),
        elevation: 0,
      ),
    );
    return expanded ? Expanded(child: btn) : btn;
  }
}

// ─── CARD INFORMATIVA (contenitore sezione) ───────────────────────────────────

class WfmCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const WfmCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(kSpacingLg),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusMd),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── COUNTER PILL (contatori scheda: Operazioni, Componenti…) ──────────────────

class WfmCountPill extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;

  const WfmCountPill({
    super.key,
    required this.icon,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: 4),
          Text('$count',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ─── INDICATORE DI CARICAMENTO A TUTTO SCHERMO ─────────────────────────────────

class WfmLoading extends StatelessWidget {
  final String? message;
  const WfmLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 2.6),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: AppTextStyles.bodyMedium),
          ],
        ],
      ),
    );
  }
}

// ─── STATO DI ERRORE (con retry) ───────────────────────────────────────────────

class WfmErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const WfmErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                  color: AppColors.statusReceivedBg, shape: BoxShape.circle),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 36, color: AppColors.accentRed),
            ),
            const SizedBox(height: 20),
            const Text('Si è verificato un problema',
                style: AppTextStyles.headingMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Riprova'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
