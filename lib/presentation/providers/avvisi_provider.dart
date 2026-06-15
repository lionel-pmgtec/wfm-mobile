import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/result.dart';
import '../../domain/entities/entities.dart';
import 'core_providers.dart';

final avvisiQueryProvider = StateProvider<String>((ref) => '');

final avvisiProvider = FutureProvider<List<NotificationAvviso>>((ref) async {
  final query = ref.watch(avvisiQueryProvider);
  final repo = ref.watch(notificationRepositoryProvider);
  final res = await repo.getAvvisi(query: query.isEmpty ? null : query);
  return res.when(
    success: (l) => l,
    failure: (f) => throw Exception(f.message),
  );
});

final avvisoDetailProvider =
    FutureProvider.family<NotificationAvviso, String>((ref, numero) async {
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
