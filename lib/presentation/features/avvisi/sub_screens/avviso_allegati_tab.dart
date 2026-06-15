// Tab "Allegati" — gestione documenti embeddata direttamente nel detail.
// Niente full-screen push: tutto inline (camera, galleria, file picker,
// categoria via dialog, eliminazione swipe/tap).

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/image_compression_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../domain/entities/entities.dart';
import '../../../providers/avviso_extension_provider.dart';

class AvvisoAllegatiTab extends ConsumerStatefulWidget {
  final String numeroAvviso;
  const AvvisoAllegatiTab({super.key, required this.numeroAvviso});

  @override
  ConsumerState<AvvisoAllegatiTab> createState() =>
      _AvvisoAllegatiTabState();
}

class _AvvisoAllegatiTabState extends ConsumerState<AvvisoAllegatiTab> {
  AvvisoDocumentoCategoria? _filtroCategoria;

  @override
  Widget build(BuildContext context) {
    final ext = ref.watch(avvisoExtensionProvider(widget.numeroAvviso));
    final docs = _filtroCategoria == null
        ? ext.documenti
        : ext.documenti.where((d) => d.categoria == _filtroCategoria).toList();

    final counts = <AvvisoDocumentoCategoria, int>{
      for (final c in AvvisoDocumentoCategoria.values) c: 0,
    };
    for (final d in ext.documenti) {
      counts[d.categoria] = (counts[d.categoria] ?? 0) + 1;
    }

    return Column(
      children: [
        // Filtro categorie (chip scrollabili).
        SizedBox(
          height: 50,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text('Tutti (${ext.documenti.length})'),
                  selected: _filtroCategoria == null,
                  onSelected: (_) =>
                      setState(() => _filtroCategoria = null),
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _filtroCategoria == null
                          ? Colors.white
                          : AppColors.primary),
                ),
              ),
              for (final c in AvvisoDocumentoCategoria.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(c.icon,
                        size: 16,
                        color: _filtroCategoria == c
                            ? Colors.white
                            : c.color),
                    label: Text('${c.label} (${counts[c] ?? 0})'),
                    selected: _filtroCategoria == c,
                    onSelected: (_) => setState(() => _filtroCategoria = c),
                    showCheckmark: false,
                    selectedColor: c.color,
                    labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _filtroCategoria == c
                            ? Colors.white
                            : c.color),
                  ),
                ),
            ],
          ),
        ),
        // Lista documenti.
        Expanded(
          child: docs.isEmpty
              ? const EmptyState(
                  title: 'Nessun documento',
                  subtitle: 'Aggiungi una foto, un PDF o un file.',
                  icon: Icons.cloud_upload_outlined,
                )
              : ListView.separated(
                  padding: kPagePadding,
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _DocTile(
                    doc: docs[i],
                    onDelete: () => ref
                        .read(avvisoExtensionProvider(widget.numeroAvviso)
                            .notifier)
                        .removeDocumento(docs[i].id),
                  ),
                ),
        ),
        // FAB inline (in basso a destra).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showAddMenu,
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi documento'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddMenu() async {
    final source = await showModalBottomSheet<_AddSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Scatta foto'),
              onTap: () => Navigator.pop(context, _AddSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Scegli dalla galleria'),
              onTap: () => Navigator.pop(context, _AddSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Carica file'),
              onTap: () => Navigator.pop(context, _AddSource.file),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final cat = await _pickCategoria(
      defaultCat: source == _AddSource.file
          ? AvvisoDocumentoCategoria.documentoCliente
          : AvvisoDocumentoCategoria.fotoCantiere,
    );
    if (cat == null || !mounted) return;
    String? path;
    String? fileName;
    String mime = 'application/octet-stream';
    switch (source) {
      case _AddSource.camera:
      case _AddSource.gallery:
        final img = await ImagePicker().pickImage(
          source: source == _AddSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
          imageQuality: 90,
        );
        if (img == null) return;
        final compressed =
            await ImageCompressionService.instance.compress(img.path);
        path = compressed?.path ?? img.path;
        fileName = img.name;
        mime = 'image/jpeg';
        break;
      case _AddSource.file:
        final res = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx'],
        );
        if (res == null || res.files.isEmpty) return;
        path = res.files.first.path;
        fileName = res.files.first.name;
        if (fileName.toLowerCase().endsWith('.pdf')) {
          mime = 'application/pdf';
        }
        break;
    }
    if (path == null) return;
    final stat = await File(path).stat();
    final doc = AvvisoDocumento(
      id: 'DOC-${DateTime.now().millisecondsSinceEpoch}',
      categoria: cat,
      fileName: fileName,
      filePath: path,
      mimeType: mime,
      sizeBytes: stat.size,
      createdAt: DateTime.now(),
    );
    await ref
        .read(avvisoExtensionProvider(widget.numeroAvviso).notifier)
        .addDocumento(doc);
    if (mounted) setState(() => _filtroCategoria = cat);
  }

  Future<AvvisoDocumentoCategoria?> _pickCategoria(
      {required AvvisoDocumentoCategoria defaultCat}) {
    AvvisoDocumentoCategoria current = defaultCat;
    return showDialog<AvvisoDocumentoCategoria>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSt) {
          final maxW = MediaQuery.of(ctx).size.width - 40;
          return AlertDialog(
            title: const Text('Categoria documento'),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                  minWidth: maxW.clamp(280.0, 560.0), maxWidth: 560),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: AvvisoDocumentoCategoria.values
                  .map((c) => RadioListTile<AvvisoDocumentoCategoria>(
                        value: c,
                        // ignore: deprecated_member_use
                        groupValue: current,
                        // ignore: deprecated_member_use
                        onChanged: (v) =>
                            setSt(() => current = v ?? current),
                        title: Row(children: [
                          Icon(c.icon, color: c.color, size: 18),
                          const SizedBox(width: 8),
                          Text(c.label),
                        ]),
                      ))
                  .toList(),
            ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annulla')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, current),
                  child: const Text('Conferma')),
            ],
          );
        });
      },
    );
  }
}

enum _AddSource { camera, gallery, file }

class _DocTile extends StatelessWidget {
  final AvvisoDocumento doc;
  final Future<void> Function() onDelete;
  const _DocTile({required this.doc, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return WfmCard(
      padding: const EdgeInsets.all(12),
      onTap: () => _open(doc),
      child: Row(children: [
        if (doc.isImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(doc.filePath),
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _icon(doc)),
          )
        else
          _icon(doc),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(doc.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headingSmall),
              const SizedBox(height: 2),
              Text(doc.categoria.label,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: doc.categoria.color, fontWeight: FontWeight.w600)),
              Text('${_size(doc.sizeBytes)} · ${Fmt.dateTime(doc.createdAt)}',
                  style: AppTextStyles.bodySmall),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.accentRed),
          onPressed: () async {
            final ok = await showWfmConfirmDialog(
              context: context,
              title: 'Elimina documento',
              message: 'Vuoi eliminare ${doc.fileName}?',
              confirmLabel: 'Elimina',
              tone: WfmDialogTone.danger,
            );
            if (ok == true) await onDelete();
          },
        ),
      ]),
    );
  }

  Widget _icon(AvvisoDocumento d) => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: d.categoria.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(d.isPdf ? Icons.picture_as_pdf_outlined : d.categoria.icon,
            color: d.categoria.color),
      );

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  Future<void> _open(AvvisoDocumento d) async {
    final uri = Uri.file(d.filePath);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
