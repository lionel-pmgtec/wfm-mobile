// Validatori di campo riutilizzabili nei Form.

class Validators {
  static String? required(String? v, {String message = 'Campo obbligatorio'}) {
    if (v == null || v.trim().isEmpty) return message;
    return null;
  }

  static String? number(String? v, {bool allowEmpty = false}) {
    if (v == null || v.trim().isEmpty) {
      return allowEmpty ? null : 'Campo obbligatorio';
    }
    if (num.tryParse(v.replaceAll(',', '.')) == null) {
      return 'Valore numerico non valido';
    }
    return null;
  }

  /// Lettura contatore: numerica e ≥ lettura precedente (specifiche EF-M6.2).
  static String? meterReading(String? v, {num? previous}) {
    final base = number(v);
    if (base != null) return base;
    final value = num.parse(v!.replaceAll(',', '.'));
    if (previous != null && value < previous) {
      return 'Deve essere ≥ lettura precedente ($previous)';
    }
    return null;
  }

  static String? phone(String? v, {bool allowEmpty = true}) {
    if (v == null || v.trim().isEmpty) return allowEmpty ? null : 'Obbligatorio';
    final ok = RegExp(r'^[0-9+ ]{6,15}$').hasMatch(v.trim());
    return ok ? null : 'Numero di telefono non valido';
  }
}
