// Provider pour l'import de fichiers Excel dans la liste des ODL.

import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Résultat de l'analyse du fichier Excel ───────────────────────────────────

class ExcelImportResult {
  final int rowsFound;
  final int rowsImported;
  final int rowsSkipped;
  final List<String> errors;
  final List<Map<String, dynamic>> rows;

  const ExcelImportResult({
    required this.rowsFound,
    required this.rowsImported,
    required this.rowsSkipped,
    required this.errors,
    required this.rows,
  });
}

// ─── State ────────────────────────────────────────────────────────────────────

class ExcelImportState {
  final bool isLoading;
  final String? fileName;
  final ExcelImportResult? result;
  final String? error;

  const ExcelImportState({
    this.isLoading = false,
    this.fileName,
    this.result,
    this.error,
  });

  ExcelImportState copyWith({
    bool? isLoading,
    String? fileName,
    ExcelImportResult? result,
    String? error,
  }) =>
      ExcelImportState(
        isLoading: isLoading ?? this.isLoading,
        fileName: fileName ?? this.fileName,
        result: result ?? this.result,
        error: error,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ExcelImportNotifier extends StateNotifier<ExcelImportState> {
  ExcelImportNotifier() : super(const ExcelImportState());

  /// Analyse le fichier Excel et extrait les données ODL.
  Future<void> importFile(String filePath) async {
    state = const ExcelImportState(isLoading: true);
    try {
      final bytes = File(filePath).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      final fileName = filePath.split(Platform.pathSeparator).last;
      final rows = <Map<String, dynamic>>[];
      final errors = <String>[];
      int skipped = 0;

      // Prende il primo foglio
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName];
      if (sheet == null) throw Exception('Foglio Excel vuoto');

      // Prima riga = intestazioni
      if (sheet.rows.isEmpty) throw Exception('Nessun dato trovato');
      final headers = sheet.rows.first
          .map((c) => c?.value?.toString().trim() ?? '')
          .toList();

      for (var i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final map = <String, dynamic>{};
        for (var j = 0; j < headers.length && j < row.length; j++) {
          map[headers[j]] = row[j]?.value;
        }

        // Validazione minima: deve avere un numero ODL o una colonna simile
        final hasCode = map.values.any((v) => v != null && v.toString().isNotEmpty);
        if (!hasCode) {
          skipped++;
          continue;
        }
        rows.add(map);
      }

      // TODO: passare rows al repository per creare/aggiornare gli ODL via API
      state = ExcelImportState(
        isLoading: false,
        fileName: fileName,
        result: ExcelImportResult(
          rowsFound: sheet.rows.length - 1,
          rowsImported: rows.length,
          rowsSkipped: skipped,
          errors: errors,
          rows: rows,
        ),
      );
    } catch (e) {
      state = ExcelImportState(isLoading: false, error: e.toString());
    }
  }

  void reset() => state = const ExcelImportState();
}

final excelImportProvider =
    StateNotifierProvider<ExcelImportNotifier, ExcelImportState>(
  (ref) => ExcelImportNotifier(),
);
