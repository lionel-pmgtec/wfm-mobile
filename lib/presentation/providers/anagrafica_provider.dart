import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/entities.dart';
import 'core_providers.dart';

final causeCodesProvider = FutureProvider<List<CodeLabel>>((ref) async {
  final res = await ref.watch(anagraficaRepositoryProvider).getCauseCodes();
  return res.valueOrNull ?? const [];
});

final solutionCodesProvider = FutureProvider<List<CodeLabel>>((ref) async {
  final res = await ref.watch(anagraficaRepositoryProvider).getSolutionCodes();
  return res.valueOrNull ?? const [];
});

final warehousesProvider = FutureProvider<List<Warehouse>>((ref) async {
  final res = await ref.watch(anagraficaRepositoryProvider).getWarehouses();
  return res.valueOrNull ?? const [];
});

final meterBrandsProvider = FutureProvider<List<String>>((ref) async {
  final res = await ref.watch(anagraficaRepositoryProvider).getMeterBrands();
  return res.valueOrNull ?? const [];
});

final tamCodesProvider = FutureProvider<List<String>>((ref) async {
  final res = await ref.watch(anagraficaRepositoryProvider).getTamCodes();
  return res.valueOrNull ?? const [];
});

/// Ricerca materiali (scheda Componenti / aggiunta materiale).
final materialSearchProvider =
    FutureProvider.family<List<MaterialItem>, String>((ref, query) async {
  final res = await ref
      .watch(anagraficaRepositoryProvider)
      .getMaterials(query: query.isEmpty ? null : query);
  return res.valueOrNull ?? const [];
});
