import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/error/failures.dart';
import '../../core/services/fcm_service.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'core_providers.dart';

/// Stato di autenticazione.
sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Authenticated extends AuthState {
  final AppUser user;
  const Authenticated(this.user);
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository repo;
  AuthController(this.repo) : super(const AuthInitial());

  AppUser? get user => repo.currentUser;

  Future<bool> login(String cid, String password) async {
    state = const AuthLoading();
    final result = await repo.login(cid, password);
    return result.when(
      success: (u) {
        state = Authenticated(u);
        _registerFcmToken();
        return true;
      },
      failure: (Failure f) {
        state = AuthError(f.message);
        return false;
      },
    );
  }

  Future<void> _registerFcmToken() async {
    // Bridge: ottieni il token push e registralo presso il Cruscotto.
    // Eseguito in fire-and-forget: l'eventuale fallimento non blocca la UI.
    final fcm = FcmService.instance;
    fcm.onTokenAvailable = repo.registerDeviceToken;
    final token = await fcm.requestPermissionAndToken();
    if (token != null) {
      await repo.registerDeviceToken(token);
    }
  }

  Future<void> logout() async {
    await repo.logout();
    state = const AuthInitial();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>(
        (ref) => AuthController(ref.watch(authRepositoryProvider)));
