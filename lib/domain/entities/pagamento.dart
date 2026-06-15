// Pagamento (spec §12) — collegato a un Preventivo / Avviso.

import 'enums.dart';

class Pagamento {
  final String id;
  final num importo;
  final DateTime dataPagamento;
  final MetodoPagamento metodo;
  final EsitoPagamento esito;
  final String? riferimento; // numero ricevuta / IBAN / ...
  final String note;
  final DateTime createdAt;

  const Pagamento({
    required this.id,
    required this.importo,
    required this.dataPagamento,
    required this.metodo,
    this.esito = EsitoPagamento.riuscito,
    this.riferimento,
    this.note = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'importo': importo,
        'dataPagamento': dataPagamento.toIso8601String(),
        'metodo': metodo.name,
        'esito': esito.name,
        'riferimento': riferimento,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Pagamento.fromJson(Map json) => Pagamento(
        id: json['id'] as String,
        importo: (json['importo'] as num),
        dataPagamento: DateTime.parse(json['dataPagamento'] as String),
        metodo: MetodoPagamento.values.firstWhere(
            (m) => m.name == json['metodo'],
            orElse: () => MetodoPagamento.contanti),
        esito: EsitoPagamento.values.firstWhere(
            (e) => e.name == json['esito'],
            orElse: () => EsitoPagamento.riuscito),
        riferimento: json['riferimento'] as String?,
        note: (json['note'] as String?) ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
