import 'user.dart';

/// Sessione di autenticazione restituita dal middleware al login.
///
/// Incapsula l'utente autenticato, il token di sessione (Bearer, da allegare
/// nell'header Authorization delle richieste successive) e la sua scadenza.
/// In modalità mock il token è un valore fittizio; in modalità HTTP proviene
/// dalla risposta del middleware (`/auth/login`).
class AuthSession {
  final AppUser user;
  final String token;
  final DateTime expiresAt;

  const AuthSession({
    required this.user,
    required this.token,
    required this.expiresAt,
  });
}
