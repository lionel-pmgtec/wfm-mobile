// Componenti riutilizzabili dell'applicazione WFM

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── STATUS BADGE ─────────────────────────────────────────────────────────────

class StatusBadge extends StatelessWidget {
  final String stato;
  final bool small;

  const StatusBadge({super.key, required this.stato, this.small = false});

  @override
  Widget build(BuildContext context) {
    final style = getStatusStyle(stato);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          fontSize: small ? 10 : 11,
          fontWeight: FontWeight.w600,
          color: style.color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─── INTESTAZIONE SEZIONE ─────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
      child: Row(
        children: [
          Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              )),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                ).copyWith()),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─── FIELD ROW (sola lettura / modificabile) ──────────────────────────────────

class FieldRow extends StatelessWidget {
  final String label;
  final String value;
  final bool editable;
  final bool fullWidth;
  final Widget? trailing;
  final TextEditingController? controller;
  final int maxLines;
  /// Se true e il valore è vuoto (non editabile), il widget non viene renderizzato.
  /// Permette ai form di adattarsi al tipo di OdL nascondendo i campi inutili.
  final bool hideIfEmpty;

  const FieldRow({
    super.key,
    required this.label,
    required this.value,
    this.editable = false,
    this.fullWidth = false,
    this.trailing,
    this.controller,
    this.maxLines = 1,
    this.hideIfEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = controller?.text ?? value;
    if (hideIfEmpty && !editable && displayValue.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: editable ? AppColors.surface : AppColors.surfaceVariant,
        border: Border.all(color: editable ? AppColors.primary : AppColors.border, width: editable ? 2 : 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTextStyles.fieldLabel),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: editable
                    ? TextFormField(
                        controller: controller,
                        initialValue: controller == null ? value : null,
                        maxLines: maxLines,
                        style: AppTextStyles.fieldValue,
                        decoration: InputDecoration(
                          hintText: displayValue.isEmpty ? '—' : null,
                          hintStyle: AppTextStyles.fieldValue
                              .copyWith(color: AppColors.textSecondary),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      )
                    : Text(
                        displayValue.isEmpty ? '—' : displayValue,
                        style: AppTextStyles.fieldValueReadOnly,
                      ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ],
      ),
    );
  }
}

// ─── FORM GRID (responsive 2 colonne) ────────────────────────────────────────

class FormGrid extends StatelessWidget {
  final List<Widget> children;

  const FormGrid({super.key, required this.children});

  /// Filtra le FieldRow nascoste (hideIfEmpty=true + value vuoto): in questo modo
  /// il form si adatta al tipo di OdL senza mostrare righe vuote.
  ///
  /// Riconosce sia [FieldRow] direttamente sia wrapper noti che espongono
  /// gli stessi attributi tramite duck-typing dinamico (es. SapLockedField).
  /// Questo evita "buchi" nella griglia 2 colonne quando un wrapper si
  /// auto-nasconde con SizedBox.shrink().
  List<Widget> _visibleChildren() {
    return children.where((w) {
      // Caso diretto : FieldRow.
      if (w is FieldRow) {
        final displayValue = w.controller?.text ?? w.value;
        if (w.hideIfEmpty && !w.editable && displayValue.trim().isEmpty) {
          return false;
        }
        return true;
      }
      // Caso wrapper : verifica via duck-typing se il widget ha
      // un getter `hideIfEmpty` (bool) e `value` (String) ed è vuoto.
      try {
        final dynamic dyn = w;
        final hideIfEmpty = dyn.hideIfEmpty as bool;
        final value = (dyn.value as String).trim();
        if (hideIfEmpty && value.isEmpty) return false;
      } catch (_) {
        // Non è un wrapper compatibile: lascia passare.
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;
    final visible = _visibleChildren();
    if (visible.isEmpty) return const SizedBox.shrink();

    if (isTablet) {
      // 2 colonne su tablet
      final rows = <Widget>[];
      for (var i = 0; i < visible.length; i += 2) {
        rows.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: visible[i]),
            const SizedBox(width: 12),
            Expanded(
                child: i + 1 < visible.length
                    ? visible[i + 1]
                    : const SizedBox()),
          ],
        ));
        if (i + 2 < visible.length) rows.add(const SizedBox(height: 12));
      }
      return Column(children: rows);
    }

    // 1 colonna su mobile
    return Column(
      children:
          visible.expand((w) => [w, const SizedBox(height: 12)]).toList()
            ..removeLast(),
    );
  }
}

// ─── SHIMMER DI CARICAMENTO ───────────────────────────────────────────────────

class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius = 6,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: const [
                Color(0xFFEEEEEE),
                Color(0xFFF8F8F8),
                Color(0xFFEEEEEE),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── SHIMMER ELEMENTO LISTA OdL ───────────────────────────────────────────────

class WorkOrderShimmerItem extends StatelessWidget {
  const WorkOrderShimmerItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ShimmerBox(width: 80, height: 14),
            Spacer(),
            ShimmerBox(width: 60, height: 22, borderRadius: 20),
          ]),
          SizedBox(height: 8),
          ShimmerBox(height: 16),
          SizedBox(height: 6),
          ShimmerBox(width: 200, height: 13),
          SizedBox(height: 10),
          Row(children: [
            ShimmerBox(width: 80, height: 13),
            SizedBox(width: 12),
            ShimmerBox(width: 60, height: 13),
          ]),
        ],
      ),
    );
  }
}

// ─── STATO VUOTO ──────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onRefresh;

  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.onRefresh,
  });

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
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: AppTextStyles.headingMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            if (onRefresh != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Aggiorna'),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

// ─── SAP TOAST ────────────────────────────────────────────────────────────────

void showSapToast(BuildContext context, String message,
    {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
        ],
      ),
      backgroundColor: isError ? AppColors.accentRed : AppColors.accentGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ),
  );
}
