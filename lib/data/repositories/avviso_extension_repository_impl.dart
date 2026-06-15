// Implementazione del repository AvvisoExtension.
//
// Strategia di persistenza:
//   - Tenta di usare Hive (box `avviso_extensions`) — apertura lazy
//   - Fallback in-memory se Hive non è disponibile (test/web mockate)
//
// La chiave nel box è il numero avviso. Il valore è il JSON serializzato.

import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/avviso_extension.dart';
import '../../domain/repositories/avviso_extension_repository.dart';

class AvvisoExtensionRepositoryImpl implements AvvisoExtensionRepository {
  static const String _boxName = 'avviso_extensions';

  Box<String>? _box;
  // Cache in-memory utilizzata come fallback e per evitare letture ripetute.
  final Map<String, AvvisoExtension> _cache = {};
  Future<void>? _initFuture;

  Future<void> _ensureInit() {
    return _initFuture ??= _init();
  }

  Future<void> _init() async {
    try {
      if (!Hive.isAdapterRegistered(0)) {
        await Hive.initFlutter();
      }
      _box = await Hive.openBox<String>(_boxName);
    } catch (_) {
      // Hive non disponibile (es. test): si lavora in memoria.
      _box = null;
    }
  }

  @override
  Future<AvvisoExtension> get(String numeroAvviso) async {
    await _ensureInit();
    if (_cache.containsKey(numeroAvviso)) return _cache[numeroAvviso]!;
    final raw = _box?.get(numeroAvviso);
    if (raw == null) {
      return AvvisoExtension.empty(numeroAvviso);
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final ext = AvvisoExtension.fromJson(map);
      _cache[numeroAvviso] = ext;
      return ext;
    } catch (_) {
      return AvvisoExtension.empty(numeroAvviso);
    }
  }

  @override
  Future<void> save(AvvisoExtension extension) async {
    await _ensureInit();
    _cache[extension.avvisoNumero] = extension;
    final raw = jsonEncode(extension.toJson());
    await _box?.put(extension.avvisoNumero, raw);
  }

  @override
  Future<List<String>> savedAvvisi() async {
    await _ensureInit();
    final keys = _box?.keys.cast<String>().toList() ?? _cache.keys.toList();
    return keys;
  }

  @override
  Future<void> clear(String numeroAvviso) async {
    await _ensureInit();
    _cache.remove(numeroAvviso);
    await _box?.delete(numeroAvviso);
  }
}
