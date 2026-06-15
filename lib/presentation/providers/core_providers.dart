// Injection de dépendances (Riverpod). Punto unico di costruzione di
// config, datasources e repository. Cambiare l'implementazione qui (mock <->
// http) NON impatta la UI.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/network/dio_client.dart';

import '../../data/datasources/local/local_data_source.dart';
import '../../data/datasources/remote/remote_data_source.dart';
import '../../data/datasources/remote/mock_remote_data_source.dart';
import '../../data/datasources/remote/http_remote_data_source.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/work_order_repository_impl.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../data/repositories/esito_repository_impl.dart';
import '../../data/repositories/attachment_repository_impl.dart';
import '../../data/repositories/anagrafica_repository_impl.dart';
import '../../data/repositories/sync_repository_impl.dart';
import '../../data/repositories/avviso_extension_repository_impl.dart';
import '../../data/repositories/odl_extension_repository_impl.dart';

import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/work_order_repository.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/repositories/esito_repository.dart';
import '../../domain/repositories/attachment_repository.dart';
import '../../domain/repositories/anagrafica_repository.dart';
import '../../domain/repositories/sync_repository.dart';
import '../../domain/repositories/avviso_extension_repository.dart';
import '../../domain/repositories/odl_extension_repository.dart';

// ─── CONFIG & SERVIZI DI BASE ─────────────────────────────────────────────

final appConfigProvider = Provider<AppConfig>((ref) => kAppConfig);

final connectivityProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(service.dispose);
  return service;
});

// Stocke le token courant sans créer de dépendance circulaire.
final authTokenProvider = StateProvider<String?>((ref) => null);

final dioClientProvider = Provider<DioClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return DioClient(
    config: config,
    tokenProvider: () async => ref.read(authTokenProvider),
  );
});

// ─── DATASOURCES ───────────────────────────────────────────────────────────

final localDataSourceProvider = Provider<WfmLocalDataSource>(
  (ref) => InMemoryLocalDataSource(),
);

/// Sceglie mock o HTTP in base alla configurazione (useMockData).
final remoteDataSourceProvider = Provider<WfmRemoteDataSource>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockData) return MockRemoteDataSource();
  return HttpRemoteDataSource(ref.watch(dioClientProvider));
});

// ─── REPOSITORIES ──────────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    ref.watch(remoteDataSourceProvider),
    onTokenChanged: (token) => ref.read(authTokenProvider.notifier).state = token,
  ),
);

final syncRepositoryProvider = Provider<SyncRepository>(
  (ref) => SyncRepositoryImpl(ref.watch(localDataSourceProvider)),
);

final workOrderRepositoryProvider = Provider<WorkOrderRepository>(
  (ref) => WorkOrderRepositoryImpl(
    ref.watch(remoteDataSourceProvider),
    ref.watch(localDataSourceProvider),
    ref.watch(connectivityProvider),
  ),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepositoryImpl(ref.watch(remoteDataSourceProvider)),
);

final esitoRepositoryProvider = Provider<EsitoRepository>(
  (ref) => EsitoRepositoryImpl(
    ref.watch(remoteDataSourceProvider),
    ref.watch(localDataSourceProvider),
    ref.watch(connectivityProvider),
    ref.watch(syncRepositoryProvider),
  ),
);

final attachmentRepositoryProvider = Provider<AttachmentRepository>(
  (ref) => AttachmentRepositoryImpl(
    ref.watch(remoteDataSourceProvider),
    ref.watch(localDataSourceProvider),
    ref.watch(connectivityProvider),
  ),
);

final anagraficaRepositoryProvider = Provider<AnagraficaRepository>(
  (ref) => AnagraficaRepositoryImpl(ref.watch(remoteDataSourceProvider)),
);

/// Repository per i dati LOCALI estesi dell'Avviso (preventivo, permessi,
/// lavori cliente, documenti, sospensioni, note). Persistenza Hive.
final avvisoExtensionRepositoryProvider =
    Provider<AvvisoExtensionRepository>((ref) => AvvisoExtensionRepositoryImpl());

/// Repository per i dati LOCALI estesi dell'OdL (attivita, appuntamenti,
/// sospensioni, firme, chiusura, note). Persistenza Hive.
final odlExtensionRepositoryProvider =
    Provider<OdlExtensionRepository>((ref) => OdlExtensionRepositoryImpl());
