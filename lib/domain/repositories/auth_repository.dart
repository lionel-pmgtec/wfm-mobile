import '../../core/network/result.dart';
import '../entities/user.dart';

/// Contratto di autenticazione (M1). Implementazione mock o remota (middleware).
abstract interface class AuthRepository {
  /// Login con CID + password. In caso di successo restituisce l'utente.
  Future<Result<AppUser>> login(String cid, String password);

  /// Disconnessione: revoca token e pulizia sessione.
  Future<void> logout();

  /// Riconnessione automatica se il token è ancora valido (EF-M1.2).
  Future<AppUser?> tryAutoLogin();

  /// Utente attualmente connesso (null se disconnesso).
  AppUser? get currentUser;

  /// Token di sessione corrente (per gli interceptor Dio).
  Future<String?> currentToken();

  /// Registra il token FCM presso il Cruscotto (middleware).
  /// Chiamato dopo il login quando il token push è disponibile.
  Future<void> registerDeviceToken(String fcmToken);
}
