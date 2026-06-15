// Bottom sheet pour importer des ODL depuis un fichier Excel.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../providers/excel_import_provider.dart';

Future<void> showExcelImportSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: const _ExcelImportSheet(),
    ),
  );
}

class _ExcelImportSheet extends ConsumerWidget {
  const _ExcelImportSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(excelImportProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.table_chart_outlined,
                    color: AppColors.accentGreen, size: 22),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Import Excel',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  Text('Importa OdL da un file .xlsx',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  ref.read(excelImportProvider.notifier).reset();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close_rounded),
                color: AppColors.textHint,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Zone drop / sélection fichier
          if (state.result == null && !state.isLoading) ...[
            _PickerZone(
              onPick: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['xlsx', 'xls'],
                  allowMultiple: false,
                );
                if (result != null && result.files.single.path != null) {
                  ref
                      .read(excelImportProvider.notifier)
                      .importFile(result.files.single.path!);
                }
              },
            ),
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.accentRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(state.error!,
                          style: const TextStyle(
                              color: AppColors.accentRed, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
          ],

          // Chargement
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analyse du fichier Excel…',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),

          // Résultat
          if (state.result != null) ...[
            _ResultCard(result: state.result!, fileName: state.fileName ?? ''),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(excelImportProvider.notifier).reset(),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Nuovo file'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '${state.result!.rowsImported} OdL importati con successo'),
                          backgroundColor: AppColors.accentGreen,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      ref.read(excelImportProvider.notifier).reset();
                    },
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Applica'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Zone de sélection fichier ────────────────────────────────────────────────

class _PickerZone extends StatelessWidget {
  final VoidCallback onPick;
  const _PickerZone({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.backgroundPage,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.border,
            width: 1.5,
            // dashed effect via BoxDecoration not supported natively;
            // use solid border for simplicity
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.upload_file_rounded,
                  color: AppColors.accentGreen, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tocca per selezionare un file',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Formati accettati: .xlsx, .xls',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accentGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Sfoglia',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Carte de résultat ───────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final ExcelImportResult result;
  final String fileName;
  const _ResultCard({required this.result, required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundPage,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insert_drive_file_outlined,
                  color: AppColors.accentGreen, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(fileName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _statRow('Righe trovate', '${result.rowsFound}', AppColors.textPrimary),
          const SizedBox(height: 6),
          _statRow('OdL importati', '${result.rowsImported}', AppColors.accentGreen),
          if (result.rowsSkipped > 0) ...[
            const SizedBox(height: 6),
            _statRow('Righe ignorate', '${result.rowsSkipped}', AppColors.accentOrange),
          ],
          if (result.errors.isNotEmpty) ...[
            const SizedBox(height: 6),
            _statRow('Errori', '${result.errors.length}', AppColors.accentRed),
          ],
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ),
      ],
    );
  }
}
