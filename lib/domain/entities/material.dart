// Materiale (anagrafica) e utilizzo materiale.

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

  /// Giacenza PER MAGAZZINO (codice magazzino -> quantità), se il backend la
  /// manda (`stockPerMagazzino`). Vuota = il backend dà un solo stock.
  final Map<String, num> stockPerMagazzino;

  const MaterialItem({
    required this.materialCode,
    required this.description,
    this.unitOfMeasure = 'PZ',
    this.barcode,
    this.defaultWarehouseCode = 'W01',
    this.stockDisponibile = 0,
    this.stockPerMagazzino = const {},
  });

  MaterialItem copyWith({Map<String, num>? stockPerMagazzino}) => MaterialItem(
        materialCode: materialCode,
        description: description,
        unitOfMeasure: unitOfMeasure,
        barcode: barcode,
        defaultWarehouseCode: defaultWarehouseCode,
        stockDisponibile: stockDisponibile,
        stockPerMagazzino: stockPerMagazzino ?? this.stockPerMagazzino,
      );

  /// Giacenza di ogni magazzino in cui il materiale c'è, come la dà il
  /// backend. Se manda solo `stockDisponibile`, il materiale sta nel suo
  /// magazzino predefinito (`defaultWarehouseCode`: "dove il materiale è
  /// stoccato"): lì c'è quella quantità e negli altri nessuna.
  Map<String, num> get giacenze => stockPerMagazzino.isNotEmpty
      ? stockPerMagazzino
      : {defaultWarehouseCode: stockDisponibile};
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
