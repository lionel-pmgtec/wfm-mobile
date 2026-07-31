import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/result.dart';
import '../../domain/entities/entities.dart';
import 'core_providers.dart';
import 'creation_provider.dart';

final avvisiQueryProvider = StateProvider<String>((ref) => '');

/// Modalità "Elabora" (edit inline) per un singolo avviso (numero).
/// Attivata/disattivata dalla matita nell'AppBar del dettaglio Avviso.
/// autoDispose: si azzera automaticamente quando si lascia il dettaglio.
final avvisoEditModeProvider =
    StateProvider.autoDispose.family<bool, String>((ref, _) => false);

final avvisiProvider = FutureProvider<List<NotificationAvviso>>((ref) async {
  final query = ref.watch(avvisiQueryProvider);

  // Avvisi creati sul tablet (local-first), filtrati come i remoti e in cima.
  var locali = await ref.watch(createdAvvisiProvider.future);
  if (query.trim().isNotEmpty) {
    final needle = query.toLowerCase();
    locali = locali
        .where((a) =>
            a.numeroAvviso.toLowerCase().contains(needle) ||
            a.descrizione.toLowerCase().contains(needle))
        .toList();
  }

  final repo = ref.watch(notificationRepositoryProvider);
  try {
    final res = await repo.getAvvisi(query: query.isEmpty ? null : query);
    final remote = res.when(
      success: (l) => l,
      failure: (f) => throw Exception(f.message),
    );
    return [...locali, ...remote];
  } catch (_) {
    if (locali.isNotEmpty) return locali;
    rethrow;
  }
});

final avvisoDetailProvider =
    FutureProvider.family<NotificationAvviso, String>((ref, numero) async {
  // Prima gli avvisi creati sul tablet (id TMP): non esistono lato cruscotto.
  final locali = await ref.watch(createdAvvisiProvider.future);
  for (final a in locali) {
    if (a.numeroAvviso == numero) return a;
  }
  final repo = ref.watch(notificationRepositoryProvider);
  final res = await repo.getAvvisoDetail(numero);
  return res.when(
    success: (a) => a,
    failure: (f) => throw Exception(f.message),
  );
});

/// Azione: generazione OdL da avviso (EF-M9.3).
final generateWorkOrderProvider =
    Provider<Future<Result<WorkOrder>> Function(String)>((ref) {
  return (numero) async {
    final repo = ref.read(notificationRepositoryProvider);
    final res = await repo.generateWorkOrder(numero);
    if (res.isSuccess) ref.invalidate(avvisiProvider);
    return res;
  };
});

/// Azione: eliminazione di un avviso.
final deleteAvvisoProvider =
    Provider<Future<Result<void>> Function(String)>((ref) {
  return (numero) async {
    final repo = ref.read(notificationRepositoryProvider);
    final res = await repo.deleteAvviso(numero);
    if (res.isSuccess) ref.invalidate(avvisiProvider);
    return res;
  };
});
