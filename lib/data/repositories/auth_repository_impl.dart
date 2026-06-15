import 'package:dio/dio.dart';

import '../../core/error/failures.dart';
import '../../core/network/result.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/remote/remote_data_source.dart';

/// Implementazione auth. Il token sicuro va salvato in flutter_secure_storage
/// (qui mantenuto in memoria per l'MVP; TODO: integrare SecureKeys).
class AuthRepositoryImpl implements AuthRepository {
  final WfmRemoteDataSource remote;
  final void Function(String?)? onTokenChanged;

  AuthRepositoryImpl(this.remote, {this.onTokenChanged});

  AppUser? _user;
  String? _token;
  DateTime? _expiry;

  @override
  AppUser? get currentUser => _user;

  @override
  Future<Result<AppUser>> login(String cid, String password) async {
    try {
      final user = await remote.login(cid, password);
      _user = user;
      _token = 'token-${DateTime.now().millisecondsSinceEpoch}';
      _expiry = DateTime.now().add(const Duration(hours: 8));
      onTokenChanged?.call(_token);
      return Success(user);
    } catch (e) {
      return Err(_map(e));
    }
  }

  @override
  Future<void> logout() async {
    try {
      await remote.logout();
    } finally {
      _user = null;
      _token = null;
      _expiry = null;
      onTokenChanged?.call(null);
    }
  }

  @override
  Future<AppUser?> tryAutoLogin() async {
    if (_user != null && _expiry != null && _expiry!.isAfter(DateTime.now())) {
      return _user;
    }
    return null;
  }

  @override
  Future<String?> currentToken() async {
    if (_expiry != null && _expiry!.isBefore(DateTime.now())) return null;
    return _token;
  }

  @override
  Future<void> registerDeviceToken(String fcmToken) async {
    // In mock mode il middleware non c'è: logghiamo soltanto.
    // Implementazione HTTP reale: POST /devices { cid, fcmToken, platform }.
    try {
      await remote.registerDeviceToken(_user?.cid ?? '', fcmToken);
    } catch (_) {
      // Errore non bloccante: il token verrà ritentato al prossimo refresh.
    }
  }

  Failure _map(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionError) {
        return const NetworkFailure('Server non raggiungibile. Verificare la connessione e riprovare.');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return const NetworkFailure('Il server non risponde. Riprovare.');
      }
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        return const AuthFailure('Credenziali non valide');
      }
    }
    final msg = e.toString();
    if (msg.contains('mancanti') || msg.contains('401')) {
      return const AuthFailure('Credenziali non valide');
    }
    return const NetworkFailure('Impossibile contattare il server');
  }
}
