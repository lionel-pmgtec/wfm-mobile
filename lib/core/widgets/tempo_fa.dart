// "2 min fa": tempo trascorso da [since], aggiornato da solo.
//
// Sotto il minuto si aggiorna ogni secondo, sotto l'ora ogni 30 secondi; dopo
// non ha bisogno di un timer (si ricalcola quando la lista si ridisegna).

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/arrival_store.dart';

class TempoFa extends StatefulWidget {
  final DateTime since;
  final TextStyle? style;
  const TempoFa({super.key, required this.since, this.style});

  @override
  State<TempoFa> createState() => _TempoFaState();
}

class _TempoFaState extends State<TempoFa> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant TempoFa old) {
    super.didUpdateWidget(old);
    if (old.since != widget.since) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final age = DateTime.now().difference(widget.since);
    if (age >= const Duration(hours: 1)) return;
    _timer = Timer.periodic(
      age < const Duration(minutes: 1)
          ? const Duration(seconds: 1)
          : const Duration(seconds: 30),
      (_) {
        if (!mounted) return;
        setState(() {});
        // Passato il minuto/l'ora si cambia ritmo o ci si ferma.
        _schedule();
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
        formatTempoFa(DateTime.now().difference(widget.since)),
        style: widget.style,
      );
}
