// Firma del cliente: rappresentazione di una signature acquisita.
// Dato LOCALE, generato dall'app, legato a un Preventivo.

import 'dart:convert';
import 'dart:typed_data';

class FirmaCliente {
  final String id;
  final String nomeFirmatario;
  final DateTime firmataIl;
  /// PNG della firma (base64-encoded per persistenza JSON/Hive).
  final String pngBase64;

  const FirmaCliente({
    required this.id,
    required this.nomeFirmatario,
    required this.firmataIl,
    required this.pngBase64,
  });

  /// Bytes pronti per l'uso (decodifica base64).
  Uint8List get pngBytes => base64Decode(pngBase64);

  String get dataFormattata =>
      '${firmataIl.day.toString().padLeft(2, '0')}/'
      '${firmataIl.month.toString().padLeft(2, '0')}/'
      '${firmataIl.year}';

  String get oraFormattata =>
      '${firmataIl.hour.toString().padLeft(2, '0')}:'
      '${firmataIl.minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'nomeFirmatario': nomeFirmatario,
        'firmataIl': firmataIl.toIso8601String(),
        'pngBase64': pngBase64,
      };

  factory FirmaCliente.fromJson(Map json) => FirmaCliente(
        id: json['id'] as String,
        nomeFirmatario: json['nomeFirmatario'] as String,
        firmataIl: DateTime.parse(json['firmataIl'] as String),
        pngBase64: json['pngBase64'] as String,
      );
}
