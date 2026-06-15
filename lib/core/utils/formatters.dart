// Formattazione date/ore/numeri coerente con le specifiche (ISO 8601, locale IT).

import 'package:intl/intl.dart';

class Fmt {
  static final DateFormat _date = DateFormat('dd/MM/yyyy', 'it_IT');
  static final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm', 'it_IT');
  static final DateFormat _time = DateFormat('HH:mm', 'it_IT');

  /// Data leggibile (gg/mm/aaaa).
  static String date(DateTime? d) => d == null ? '—' : _date.format(d);

  /// Data e ora leggibili.
  static String dateTime(DateTime? d) => d == null ? '—' : _dateTime.format(d);

  /// Solo ora.
  static String time(DateTime? d) => d == null ? '—' : _time.format(d);

  /// ISO 8601 con timezone (formato richiesto dai WS SOAP, specifiche §8.2).
  static String iso(DateTime? d) => d?.toIso8601String() ?? '';

  /// Quantità con 3 decimali (precisione SOAP per le quantità).
  static String quantity(num? q) => q == null ? '—' : q.toStringAsFixed(3);

  /// Importo con 2 decimali.
  static String amount(num? a) => a == null ? '—' : a.toStringAsFixed(2);

  /// Valore o trattino se vuoto.
  static String orDash(String? s) => (s == null || s.isEmpty) ? '—' : s;
}
