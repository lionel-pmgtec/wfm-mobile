// Anagrafiche statiche (materiali, magazzini, marche, codici) — M7 / M11.2.
import '../../core/network/result.dart';
import '../entities/material.dart';
import '../entities/esito.dart';

abstract interface class AnagraficaRepository {
  Future<Result<List<MaterialItem>>> getMaterials({String? query});
  Future<Result<List<Warehouse>>> getWarehouses();
  Future<Result<List<String>>> getMeterBrands();
  Future<Result<List<String>>> getTamCodes();

  /// Cause/soluzioni per la schermata Esito (dropdown).
  Future<Result<List<CodeLabel>>> getCauseCodes();
  Future<Result<List<CodeLabel>>> getSolutionCodes();
}
