// "Assegna a": chi eseguirà l'OdL che si sta creando. Per default chi lo crea;
// si può scegliere un collega dall'elenco operatori del cruscotto (lo stesso
// di "Riassegna OdL"). Il backend assegna sempre a chi crea: il passaggio al
// collega avviene subito dopo l'invio (CreationController).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../providers/auth_provider.dart';
import '../providers/reassign_provider.dart';

class AssegnatarioField extends ConsumerWidget {
  /// CID del collega scelto; null = resta a chi crea.
  final String? value;
  final ValueChanged<String?> onChanged;

  const AssegnatarioField(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final io = ref.read(authControllerProvider.notifier).user;
    final ioCid = io?.cid ?? '';
    return ref.watch(availableOperatorsProvider).when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => _info(),
          data: (operatori) {
            final colleghi =
                operatori.where((o) => o.cid != ioCid).toList();
            if (colleghi.isEmpty) return _info();
            return MatchCodeField<String>(
              label: 'Assegna a',
              value: value ?? ioCid,
              options: [
                MatchCodeOption(
                  value: ioCid,
                  code: ioCid,
                  label: io == null ? 'io' : '${io.fullName} (io)',
                  icon: Icons.person_rounded,
                ),
                for (final o in colleghi)
                  MatchCodeOption(
                    value: o.cid,
                    code: o.cid,
                    label: o.fullName,
                    icon: Icons.person_outline_rounded,
                  ),
              ],
              onChanged: (cid) => onChanged(cid == ioCid ? null : cid),
            );
          },
        );
  }

  Widget _info() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text(
          'Elenco operatori non disponibile: l\'OdL resta assegnato a te '
          '(potrai riassegnarlo dopo).',
          style: TextStyle(fontSize: 12, color: AppColors.textHint),
        ),
      );
}
