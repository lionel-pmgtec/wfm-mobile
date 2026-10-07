import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/giacenze_magazzini_service.dart';
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

/// Priorità per la creazione OdL. Endpoint reale del backend
/// (/anagrafica/priorities): niente più priorità codificata in modo fisso.
/// L'argomento è il tipo OdL (`''` = schema ordini di default): il backend
/// sceglie lo schema giusto (es. SOST → ZS).
final orderPrioritiesProvider =
    FutureProvider.family<List<CodeLabel>, String>((ref, woType) async {
  final res = await ref
      .watch(anagraficaRepositoryProvider)
      .getPriorities(type: woType.isEmpty ? null : woType);
  return res.valueOrNull ?? const [];
});

/// Correlazione tipo ordine → tipo attività / ciclo / settore
/// (/anagrafica/wo-templates?type=). Usata per proporre il tipo attività in
/// creazione e mostrare il ciclo/settore dedotti.
final workOrderTemplatesProvider =
    FutureProvider.family<List<WorkOrderActivityTemplate>, String>((ref, woType) async {
  if (woType.isEmpty) return const <WorkOrderActivityTemplate>[];
  final res = await ref
      .watch(anagraficaRepositoryProvider)
      .getWorkOrderActivityTemplates(type: woType);
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
  final materiali = res.valueOrNull ?? const <MaterialItem>[];
  // Giacenze per magazzino: quelle del backend; dove mancano, il file generato
  // da anagrafiche.json (così un materiale si trova in più magazzini).
  final file = await ref.watch(giacenzeMagazziniProvider.future);
  return GiacenzeMagazziniService.completa(materiali, file);
});

/// Giacenze per magazzino di supporto (assets/anagrafica).
final giacenzeMagazziniProvider =
    FutureProvider<Map<String, Map<String, num>>>(
        (ref) => GiacenzeMagazziniService().carica());

/// Elenco/ricerca tecnici (Cambio CID, riassegnazione OdL).
/// Con query vuota restituisce l'elenco completo.
final techniciansProvider =
    FutureProvider.family<List<AppUser>, String>((ref, query) async {
  final res = await ref
      .watch(anagraficaRepositoryProvider)
      .getTechnicians(query: query.isEmpty ? null : query);
  return res.valueOrNull ?? const [];
});
