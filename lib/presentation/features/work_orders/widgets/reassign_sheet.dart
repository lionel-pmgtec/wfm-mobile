// Bottom sheet pour réassigner un ODL à un autre opérateur.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/user.dart';
import '../../../../domain/entities/enums.dart';
import '../../../providers/reassign_provider.dart';

/// Ouvre la bottom sheet de réassignation.
Future<void> showReassignSheet(
  BuildContext context,
  WidgetRef ref,
  String orderCode,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: _ReassignSheet(orderCode: orderCode),
    ),
  );
}

class _ReassignSheet extends ConsumerStatefulWidget {
  final String orderCode;
  const _ReassignSheet({required this.orderCode});

  @override
  ConsumerState<_ReassignSheet> createState() => _ReassignSheetState();
}

class _ReassignSheetState extends ConsumerState<_ReassignSheet> {
  AppUser? _selected;
  final _noteCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _noteCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final operatorsAsync = ref.watch(availableOperatorsProvider);
    final state = ref.watch(reassignProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.swap_horiz_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Riassegna OdL',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      Text('OdL ${widget.orderCode}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textHint,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Cerca operatore…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: AppColors.backgroundPage,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
              ),
            ),

            const SizedBox(height: 8),

            // Liste opérateurs
            Expanded(
              child: operatorsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                    child: Text('Errore: $e',
                        style: const TextStyle(color: AppColors.accentRed))),
                data: (operators) {
                  final filtered = operators
                      .where((o) =>
                          _query.isEmpty ||
                          o.fullName.toLowerCase().contains(_query) ||
                          o.cid.toLowerCase().contains(_query) ||
                          o.workCenter.toLowerCase().contains(_query))
                      .toList();

                  return ListView.separated(
                    controller: ctrl,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final op = filtered[i];
                      final isSelected = _selected?.cid == op.cid;
                      return _OperatorTile(
                        operator: op,
                        isSelected: isSelected,
                        onTap: () => setState(() => _selected = isSelected ? null : op),
                      );
                    },
                  );
                },
              ),
            ),

            // Note + bouton
            if (_selected != null) ...[
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _noteCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Note di riassegnazione (opzionale)…',
                        filled: true,
                        fillColor: AppColors.backgroundPage,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: state.isLoading ? null : _confirm,
                      icon: state.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(state.isLoading
                          ? 'Riassegnazione in corso…'
                          : 'Conferma → ${_selected!.fullName}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    if (_selected == null) return;
    await ref.read(reassignProvider.notifier).reassign(
          orderCode: widget.orderCode,
          operator: _selected!,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
    if (mounted) {
      final state = ref.read(reassignProvider);
      if (state.success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OdL riassegnato a ${_selected!.fullName}'),
            backgroundColor: AppColors.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(reassignProvider.notifier).reset();
      } else if (state.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: ${state.error}'),
            backgroundColor: AppColors.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ─── Tuile opérateur ─────────────────────────────────────────────────────────

class _OperatorTile extends StatelessWidget {
  final AppUser operator;
  final bool isSelected;
  final VoidCallback onTap;

  const _OperatorTile(
      {required this.operator,
      required this.isSelected,
      required this.onTap});

  Color _roleColor() => operator.role == UserRole.tecnicoSenior
      ? AppColors.accentGreen
      : AppColors.primary;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.06)
            : AppColors.backgroundPage,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor:
              _roleColor().withValues(alpha: 0.15),
          child: Text(
            operator.initials,
            style: TextStyle(
              color: _roleColor(),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        title: Text(
          operator.fullName,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${operator.workCenter} · ${operator.role.label}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle_rounded,
                color: AppColors.primary, size: 22)
            : null,
      ),
    );
  }
}
