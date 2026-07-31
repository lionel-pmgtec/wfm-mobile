// Outbox locale degli oggetti CREATI sul tablet (OdL e avvisi).
//
// Modello "local-first": ciò che il tecnico crea sul campo resta SUL TABLET
// (persistito in Hive) finché non viene sincronizzato verso il cruscotto.
// Ogni oggetto nasce con un id provvisorio "TMP-…"; alla sincronizzazione il
// cruscotto restituisce l'id reale e la copia locale viene rimossa.
//
// Persistenza: box Hive di stringhe JSON (stesso schema dei mapper REST), con
// una copia in memoria come rete di sicurezza se Hive non è disponibile.

import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/entities.dart';
import '../models/mappers.dart';

class LocalCreationStore {
  static const String _woBoxName = 'created_work_orders';
  static const String _avvBoxName = 'created_avvisi';

  Box<String>? _woBox;
  Box<String>? _avvBox;
  final Map<String, String> _woMem = {};
  final Map<String, String> _avvMem = {};
  Future<void>? _initFuture;

  Future<void> _ensureInit() => _initFuture ??= _init();

  Future<void> _init() async {
    try {
      await Hive.initFlutter();
      _woBox = await Hive.openBox<String>(_woBoxName);
      _avvBox = await Hive.openBox<String>(_avvBoxName);
      // Allinea la copia in memoria a quanto già persistito.
      for (final k in _woBox!.keys) {
        _woMem[k as String] = _woBox!.get(k)!;
      }
      for (final k in _avvBox!.keys) {
        _avvMem[k as String] = _avvBox!.get(k)!;
      }
    } catch (_) {
      _woBox = null;
      _avvBox = null;
    }
  }

  // ── Ordini di lavoro creati ────────────────────────────────────────────────

  Future<List<WorkOrder>> workOrders() async {
    await _ensureInit();
    return _woMem.values
        .map((s) => workOrderFromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<WorkOrder?> workOrder(String code) async {
    await _ensureInit();
    final s = _woMem[code];
    return s == null
        ? null
        : workOrderFromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  Future<void> saveWorkOrder(WorkOrder order) async {
    await _ensureInit();
    final json = jsonEncode(workOrderToJson(order));
    _woMem[order.externalCode] = json;
    await _woBox?.put(order.externalCode, json);
  }

  Future<void> removeWorkOrder(String code) async {
    await _ensureInit();
    _woMem.remove(code);
    await _woBox?.delete(code);
  }

  // ── Avvisi creati ──────────────────────────────────────────────────────────

  Future<List<NotificationAvviso>> avvisi() async {
    await _ensureInit();
    return _avvMem.values
        .map((s) => avvisoFromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<NotificationAvviso?> avviso(String numero) async {
    await _ensureInit();
    final s = _avvMem[numero];
    return s == null
        ? null
        : avvisoFromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  Future<void> saveAvviso(NotificationAvviso avviso) async {
    await _ensureInit();
    final json = jsonEncode(avvisoToJson(avviso));
    _avvMem[avviso.numeroAvviso] = json;
    await _avvBox?.put(avviso.numeroAvviso, json);
  }

  Future<void> removeAvviso(String numero) async {
    await _ensureInit();
    _avvMem.remove(numero);
    await _avvBox?.delete(numero);
  }

  // ── Utilità ────────────────────────────────────────────────────────────────

  /// True se l'id è provvisorio (oggetto creato sul tablet, non ancora su SAP).
  static bool isLocalId(String id) => id.startsWith('TMP-');
}
