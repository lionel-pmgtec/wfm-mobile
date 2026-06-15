// Sezione collassabile riutilizzabile per i dettagli (DATI AVVISO,
// DATE INTERVENTO, INDIRIZZI, …).
//
// Pattern: stessa estetica di SectionHeader ma con freccia per aprire/chiudere
// e padding interno coerente.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class WfmCollapsibleSection extends StatefulWidget {
  final String title;
  final IconData? icon;
  final Widget child;
  final bool initiallyExpanded;
  final Widget? trailing;
  final String? badge;

  const WfmCollapsibleSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.initiallyExpanded = true,
    this.trailing,
    this.badge,
  });

  @override
  State<WfmCollapsibleSection> createState() => _WfmCollapsibleSectionState();
}

class _WfmCollapsibleSectionState extends State<WfmCollapsibleSection>
    with SingleTickerProviderStateMixin {
  late bool _expanded = widget.initiallyExpanded;
  late final AnimationController _ctrl = AnimationController(
    duration: const Duration(milliseconds: 220),
    vsync: this,
    value: _expanded ? 1.0 : 0.0,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  if (widget.badge != null && widget.badge!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.badge!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (widget.trailing != null) ...[
                    widget.trailing!,
                    const SizedBox(width: 4),
                  ],
                  RotationTransition(
                    turns: Tween<double>(begin: 0, end: 0.5).animate(_ctrl),
                    child: const Icon(Icons.expand_more,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: CurvedAnimation(
                parent: _ctrl, curve: Curves.easeInOutCubic),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
