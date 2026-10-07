// Pulsante "Naviga": apre l'app di navigazione del tablet con il percorso
// verso l'indirizzo (le coordinate se il backend le manda, altrimenti il testo
// dell'indirizzo). Non compare se non c'è nulla verso cui navigare.

import 'package:flutter/material.dart';

import '../../core/services/navigazione_service.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/entities/entities.dart';

class NavigaButton extends StatelessWidget {
  final Address indirizzo;
  const NavigaButton({super.key, required this.indirizzo});

  @override
  Widget build(BuildContext context) {
    final uri = NavigazioneService.uriPercorsoIndirizzo(indirizzo);
    if (uri == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton.icon(
        onPressed: () async {
          final ok = await NavigazioneService.apri(uri);
          if (!ok && context.mounted) {
            showSapToast(context, 'Nessuna app di navigazione disponibile',
                isError: true);
          }
        },
        icon: const Icon(Icons.directions_rounded, size: 18),
        label: const Text('Naviga'),
      ),
    );
  }
}
