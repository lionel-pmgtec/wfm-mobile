// Anagrafiche statiche (materiali, magazzini, marche, codici)
import '../../core/network/result.dart';
import '../entities/material.dart';
import '../entities/esito.dart';
import '../entities/equipment.dart';
import '../entities/user.dart';

abstract interface class AnagraficaRepository {
  Future<Result<List<MaterialItem>>> getMaterials({String? query});
  Future<Result<List<Warehouse>>> getWarehouses();
  Future<Result<List<String>>> getMeterBrands();
  Future<Result<List<String>>> getTamCodes();

  /// Cause/soluzioni per la schermata Esito (dropdown).
  Future<Result<List<CodeLabel>>> getCauseCodes();
  Future<Result<List<CodeLabel>>> getSolutionCodes();

  /// Ricerca equipment per matricola/barcode (Standalone).
  Future<Result<Equipment?>> getEquipment({String? matricola, String? barcode});

  /// Elenco/ricerca tecnici (Cambio CID, riassegnazione).
  Future<Result<List<AppUser>>> getTechnicians({String? query});
}
