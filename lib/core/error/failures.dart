// Gerarchia degli errori di dominio. La presentazione lavora con Failure,
// mai con eccezioni Dio/SAP grezze.

sealed class Failure {
  final String message;
  final String? code;
  const Failure(this.message, {this.code});

  @override
  String toString() => 'Failure($code): $message';
}

/// Nessuna connessione di rete.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Nessuna connessione di rete'])
      : super(code: 'NETWORK');
}

/// Errore di autenticazione (401, credenziali errate, token scaduto).
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Autenticazione fallita'])
      : super(code: 'AUTH');
}

/// Errore di business restituito dal middleware/SAP (<status>ERROR</status>).
class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code});
}

/// Errore lato cache locale (Hive).
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Errore nella cache locale'])
      : super(code: 'CACHE');
}

/// Errore di validazione locale (campi obbligatori, formati).
class ValidationFailure extends Failure {
  const ValidationFailure(super.message) : super(code: 'VALIDATION');
}

/// Errore sconosciuto/non gestito.
class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Errore imprevisto'])
      : super(code: 'UNKNOWN');
}
