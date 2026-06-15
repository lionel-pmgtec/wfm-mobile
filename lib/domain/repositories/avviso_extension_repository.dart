// Contratto del repository per AvvisoExtension (dati locali editabili).

import '../entities/avviso_extension.dart';

abstract class AvvisoExtensionRepository {
  /// Restituisce l'extension per [numeroAvviso] (o vuota se nessun dato).
  Future<AvvisoExtension> get(String numeroAvviso);

  /// Salva (overwrite) l'extension per [numeroAvviso].
  Future<void> save(AvvisoExtension extension);

  /// Elenco di tutti i numeri avviso con extension salvata.
  Future<List<String>> savedAvvisi();

  /// Rimuove tutti i dati locali per [numeroAvviso].
  Future<void> clear(String numeroAvviso);
}
