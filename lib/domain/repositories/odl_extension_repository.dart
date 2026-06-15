// Contratto repository OdlExtension.

import '../entities/odl_extension.dart';

abstract class OdlExtensionRepository {
  Future<OdlExtension> get(String odlCode);
  Future<void> save(OdlExtension extension);
  Future<void> clear(String odlCode);
}
