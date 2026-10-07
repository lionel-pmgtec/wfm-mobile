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


/// L'oggetto non esiste più (o non è più visibile) per questo tecnico: il
/// backend risponde 404 con un messaggio (es. "Ordine … non più presente in SAP").
/// Non è un guasto di rete: si scarta la copia locale e si torna alla lista.
class NonTrovatoFailure extends Failure {
  const NonTrovatoFailure(super.message) : super(code: 'NON_TROVATO');
}

/// Il pianificatore ha già inviato l'oggetto a SAP: il backend rifiuta ogni
/// scrittura con 409 `{ inviatoSap: true }`. È definitivo, non si ritenta.
class InviatoSapFailure extends Failure {
  const InviatoSapFailure(super.message) : super(code: 'INVIATO_SAP');
}

class RevocatoFailure extends Failure {
  final String? revocataIl;
  const RevocatoFailure(super.message, {this.revocataIl})
      : super(code: 'REVOCATO');
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
