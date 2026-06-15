// Implementazione OdlExtensionRepository — persistenza Hive con
// fallback in-memory (per test e per web senza Hive disponibile).

import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/odl_extension.dart';
import '../../domain/repositories/odl_extension_repository.dart';

class OdlExtensionRepositoryImpl implements OdlExtensionRepository {
  static const String _boxName = 'odl_extensions';

  Box<String>? _box;
  final Map<String, OdlExtension> _cache = {};
  Future<void>? _initFuture;

  Future<void> _ensureInit() => _initFuture ??= _init();

  Future<void> _init() async {
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox<String>(_boxName);
    } catch (_) {
      _box = null;
    }
  }

  @override
  Future<OdlExtension> get(String odlCode) async {
    await _ensureInit();
    if (_cache.containsKey(odlCode)) return _cache[odlCode]!;
    final raw = _box?.get(odlCode);
    if (raw == null) return OdlExtension.empty(odlCode);
    try {
      final ext = OdlExtension.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
      _cache[odlCode] = ext;
      return ext;
    } catch (_) {
      return OdlExtension.empty(odlCode);
    }
  }

  @override
  Future<void> save(OdlExtension extension) async {
    await _ensureInit();
    _cache[extension.odlCode] = extension;
    await _box?.put(extension.odlCode, jsonEncode(extension.toJson()));
  }

  @override
  Future<void> clear(String odlCode) async {
    await _ensureInit();
    _cache.remove(odlCode);
    await _box?.delete(odlCode);
  }
}
