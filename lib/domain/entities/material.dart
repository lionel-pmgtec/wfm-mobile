// Materiale (anagrafica) e utilizzo materiale — specifiche §9.1 + M7.

/// Materiale a catalogo (anagrafica).
class MaterialItem {
  final String materialCode;
  final String description;
  final String unitOfMeasure; // PZ, M, KG...
  final String? barcode; // EAN o codice interno
  /// Codice magazzino dove il materiale è stoccato (default warehouse del
  /// furgone tecnico). Recuperato automaticamente — nessuna scelta utente.
  final String defaultWarehouseCode;
  /// Disponibilità attuale (pezzi/m/kg in magazzino).
  final num stockDisponibile;

  const MaterialItem({
    required this.materialCode,
    required this.description,
    this.unitOfMeasure = 'PZ',
    this.barcode,
    this.defaultWarehouseCode = 'W01',
    this.stockDisponibile = 0,
  });
}

/// Materiale pianificato/utilizzato in un OdL.
class MaterialUsage {
  final String materialCode;
  final String description;
  final num plannedQuantity;
  final num usedQuantity;
  final String unitOfMeasure;
  final String warehouseCode;

  const MaterialUsage({
    required this.materialCode,
    this.description = '',
    this.plannedQuantity = 0,
    this.usedQuantity = 0,
    this.unitOfMeasure = 'PZ',
    this.warehouseCode = '',
  });

  MaterialUsage copyWith({num? usedQuantity, String? warehouseCode}) {
    return MaterialUsage(
      materialCode: materialCode,
      description: description,
      plannedQuantity: plannedQuantity,
      usedQuantity: usedQuantity ?? this.usedQuantity,
      unitOfMeasure: unitOfMeasure,
      warehouseCode: warehouseCode ?? this.warehouseCode,
    );
  }
}

/// Magazzino (anagrafica).
class Warehouse {
  final String code;
  final String name;
  const Warehouse({required this.code, this.name = ''});
}
