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

// ─── Cataloghi selezionabili dal cruscotto (niente hardcoded) ────────────────

/// Tipi OdL selezionabili (creazione/copia/genera ordine).
final workOrderTypesProvider =
    FutureProvider<List<WorkOrderTypeOption>>((ref) async {
  final res = await ref.watch(anagraficaRepositoryProvider).getWorkOrderTypes();
  return res.valueOrNull ?? const [];
});

/// Campi dinamici specifici del tipo OdL selezionato.
final workOrderFieldsProvider =
    FutureProvider.family<List<DynFieldSpec>, String>((ref, woType) async {
  if (woType.isEmpty) return const [];
  final res =
      await ref.watch(anagraficaRepositoryProvider).getWorkOrderFields(woType);
  return res.valueOrNull ?? const [];
});

/// Lookup generico per `kind` (riusabile per qualunque tendina del cruscotto).
final lookupProvider =
    FutureProvider.family<List<CodeLabel>, String>((ref, kind) async {
  final res = await ref.watch(anagraficaRepositoryProvider).getLookup(kind);
  return res.valueOrNull ?? const [];
});

/// Motivi di sospensione intervento.
final suspensionReasonsProvider =
    FutureProvider<List<CodeLabel>>((ref) async {
  return ref.watch(lookupProvider('suspension-reasons').future);
});

/// Stati utente dell'avviso.
final avvisoUserStatusesProvider =
    FutureProvider<List<CodeLabel>>((ref) async {
  return ref.watch(lookupProvider('avviso-user-statuses').future);
});

/// Priorità dell'avviso.
final avvisoPrioritiesProvider =
    FutureProvider<List<CodeLabel>>((ref) async {
  return ref.watch(lookupProvider('avviso-priorities').future);
});

/// Esiti di verifica dell'avviso.
final avvisoVerificationResultsProvider =
    FutureProvider<List<CodeLabel>>((ref) async {
  return ref.watch(lookupProvider('avviso-verification-results').future);
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

/// Elenco/ricerca tecnici (Cambio CID, riassegnazione OdL).
/// Con query vuota restituisce l'elenco completo.
final techniciansProvider =
    FutureProvider.family<List<AppUser>, String>((ref, query) async {
  final res = await ref
      .watch(anagraficaRepositoryProvider)
      .getTechnicians(query: query.isEmpty ? null : query);
  return res.valueOrNull ?? const [];
});
