// Utente (Tecnico).

import 'enums.dart';

class AppUser {
  final String cid; // Codice identificativo (login)
  final String nome;
  final String cognome;
  final String? email;
  final UserRole role;
  final String workCenter; // Centro di Lavoro
  final String? squadra;   // Squadra
  final String? tecnicoVV; // Codice Tecnico VV (struttura organizzativa nuova)

  const AppUser({
    required this.cid,
    this.nome = '',
    this.cognome = '',
    this.email,
    this.role = UserRole.tecnico,
    this.workCenter = '',
    this.squadra,
    this.tecnicoVV,
  });

  String get fullName {
    final n = [nome, cognome].where((e) => e.isNotEmpty).join(' ').trim();
    return n.isEmpty ? cid : n;
  }

  String get initials {
    final a = nome.isNotEmpty ? nome[0] : '';
    final b = cognome.isNotEmpty ? cognome[0] : '';
    final res = (a + b).toUpperCase();
    return res.isEmpty ? cid.substring(0, cid.length >= 2 ? 2 : 1).toUpperCase() : res;
  }
}
