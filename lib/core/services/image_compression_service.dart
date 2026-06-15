// Compressione foto via flutter_image_compress.
// Riduce la dimensione delle foto allegate (max ~1600 px lato lungo, qualità 80)
// prima dell'upload sul middleware.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class CompressedImage {
  final String path;
  final int sizeBytes;
  const CompressedImage({required this.path, required this.sizeBytes});
}

class ImageCompressionService {
  ImageCompressionService._();
  static final ImageCompressionService instance = ImageCompressionService._();

  /// Comprime una foto JPEG mantenendo l'orientamento EXIF.
  /// Restituisce null se la piattaforma non è supportata o se la compressione fallisce.
  Future<CompressedImage?> compress(
    String sourcePath, {
    int maxSide = 1600,
    int quality = 80,
  }) async {
    if (kIsWeb) return null;

    try {
      final dir = await getTemporaryDirectory();
      final outPath =
          '${dir.path}/wfm_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        outPath,
        minWidth: maxSide,
        minHeight: maxSide,
        quality: quality,
        keepExif: true,
        format: CompressFormat.jpeg,
      );

      if (result == null) return null;
      final length = await File(result.path).length();
      return CompressedImage(path: result.path, sizeBytes: length);
    } catch (_) {
      return null;
    }
  }
}
