// Chip per categoria/sottotipo di Avviso — usato in lista e in detail.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/entities.dart';

class WfmCategoryChip extends StatelessWidget {
  final AvvisoSubType sottotipo;
  final bool dense;

  const WfmCategoryChip({
    super.key,
    required this.sottotipo,
    this.dense = false,
  });

  Color get _color => switch (sottotipo.category) {
        AvvisoCategory.prontoIntervento => AppColors.accentOrange,
        AvvisoCategory.richiestaPreventivo => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 10,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(dense ? 4 : 10),
        border: Border.all(color: _color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(sottotipo.icon, size: dense ? 11 : 14, color: _color),
          SizedBox(width: dense ? 3 : 5),
          Text(
            sottotipo.code,
            style: TextStyle(
              fontSize: dense ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner orizzontale che mostra categoria + label sottotipo (più visibile).
class CategoryBanner extends StatelessWidget {
  final AvvisoSubType sottotipo;

  const CategoryBanner({super.key, required this.sottotipo});

  @override
  Widget build(BuildContext context) {
    final color = sottotipo.category == AvvisoCategory.prontoIntervento
        ? AppColors.accentOrange
        : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(sottotipo.category.icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sottotipo.category.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  '${sottotipo.code} · ${sottotipo.label}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
