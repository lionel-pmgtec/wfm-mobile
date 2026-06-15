// Configurazione centralizzata della navigazione (go_router) con guardia auth.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/repositories/auth_repository.dart';
import '../../presentation/providers/core_providers.dart';

import '../../presentation/features/auth/login_screen.dart';
import '../../presentation/features/home/home_screen.dart';
import '../../presentation/features/work_orders/work_orders_screen.dart';
import '../../presentation/features/work_orders/work_order_detail_screen.dart';
import '../../presentation/features/esito/esito_screen.dart';
import '../../presentation/features/meter/meter_screen.dart';
import '../../presentation/features/appointments/appointments_screen.dart';
import '../../presentation/features/avvisi/avvisi_screen.dart';
import '../../presentation/features/avvisi/avviso_detail_screen.dart';
import '../../presentation/features/create_order/create_order_screen.dart';
import '../../presentation/features/settings/settings_screen.dart';
import '../../presentation/features/settings/sync_queue_screen.dart';
import '../../presentation/features/notifications/notifications_screen.dart';
import '../../presentation/features/scanner/barcode_scanner_screen.dart';
import '../../presentation/features/signature/signature_screen.dart';
import '../../presentation/features/map/map_screen.dart';

// Sub-screens OdL
import '../../presentation/features/work_orders/sub_screens/gen_ore_screen.dart';
import '../../presentation/features/work_orders/sub_screens/copia_ordine_screen.dart';
import '../../presentation/features/work_orders/sub_screens/cambio_cid_screen.dart';
import '../../presentation/features/work_orders/sub_screens/add_componente_screen.dart';
import '../../presentation/features/work_orders/sub_screens/storico_appuntamenti_screen.dart';
import '../../presentation/features/work_orders/sub_screens/esito_appuntamento_screen.dart';
import '../../presentation/features/work_orders/sub_screens/sospensioni_screen.dart';
import '../../presentation/features/work_orders/sub_screens/dati_rqti_screen.dart';
import '../../presentation/features/work_orders/sub_screens/determina5_screen.dart';

// Sub-screens Avvisi
import '../../presentation/features/avvisi/sub_screens/elabora_avviso_screen.dart';
import '../../presentation/features/avvisi/sub_screens/genera_ordine_screen.dart';
import '../../presentation/features/avvisi/sub_screens/preventivo_screen.dart';
import '../../presentation/features/avvisi/sub_screens/preventivo_firma_screen.dart';
import '../../presentation/features/avvisi/sub_screens/preventivo_pdf_screen.dart';

// Modulo Standalone
import '../../presentation/features/standalone/standalone_menu_screen.dart';
import '../../presentation/features/standalone/equipment_detail_screen.dart';
import '../../presentation/features/standalone/sostituzione_barcode_screen.dart';
import '../../presentation/features/standalone/squadra_screen.dart';
import '../../presentation/features/standalone/templates_screen.dart';

import 'app_routes.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final AuthRepository auth = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    redirect: (context, state) {
      final loggedIn = auth.currentUser != null;
      final onLogin = state.matchedLocation == AppRoutes.login;
      if (!loggedIn && !onLogin) return AppRoutes.login;
      if (loggedIn && onLogin) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
          path: AppRoutes.login,
          builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: AppRoutes.home, builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: AppRoutes.workOrders,
        builder: (_, __) => const WorkOrdersScreen(),
      ),
      GoRoute(
        path: AppRoutes.workOrderDetail,
        builder: (_, s) =>
            WorkOrderDetailScreen(code: s.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'esito',
            builder: (_, s) => EsitoScreen(code: s.pathParameters['id']!),
          ),
          GoRoute(
            path: 'meter',
            builder: (_, s) => MeterScreen(code: s.pathParameters['id']!),
          ),
          GoRoute(
            path: 'appointments',
            builder: (_, s) =>
                AppointmentsScreen(code: s.pathParameters['id']!),
          ),
          // Sub-screens OdL
          GoRoute(
            path: 'gen-ore',
            builder: (_, s) =>
                GenOreScreen(code: s.pathParameters['id']!),
          ),
          GoRoute(
            path: 'copia',
            builder: (_, s) =>
                CopiaOrdineScreen(code: s.pathParameters['id']!),
          ),
          GoRoute(
            path: 'cambio-cid',
            builder: (_, s) =>
                CambioCidScreen(code: s.pathParameters['id']!),
          ),
          GoRoute(
            path: 'aggiungi-componente',
            builder: (_, s) =>
                AddComponenteScreen(code: s.pathParameters['id']!),
          ),
          GoRoute(
            path: 'storico-appuntamenti',
            builder: (_, s) =>
                StoricoAppuntamentiScreen(code: s.pathParameters['id']!),
          ),
          GoRoute(
            path: 'esito-appuntamento',
            builder: (_, s) =>
                EsitoAppuntamentoScreen(code: s.pathParameters['id']!),
          ),
          GoRoute(
            path: 'sospensioni',
            builder: (_, s) =>
                SospensioniScreen(code: s.pathParameters['id']!),
          ),
          GoRoute(
            path: 'rqti',
            builder: (_, s) =>
                DatiRqtiScreen(code: s.pathParameters['id']!),
          ),
          GoRoute(
            path: 'determina5',
            builder: (_, s) =>
                Determina5Screen(code: s.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.avvisi,
        builder: (_, __) => const AvvisiScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, s) =>
                AvvisoDetailScreen(numero: s.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'elabora',
                builder: (_, s) =>
                    ElaboraAvvisoScreen(numero: s.pathParameters['id']!),
              ),
              GoRoute(
                path: 'genera-ordine',
                builder: (_, s) =>
                    GeneraOrdineScreen(numero: s.pathParameters['id']!),
              ),
              GoRoute(
                path: 'preventivo',
                builder: (_, s) => PreventivoScreen(
                    numeroAvviso: s.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'firma',
                    builder: (_, s) => PreventivoFirmaScreen(
                        numeroAvviso: s.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'pdf',
                    builder: (_, s) => PreventivoPdfScreen(
                        numeroAvviso: s.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Modulo Standalone
      GoRoute(
        path: AppRoutes.standalone,
        builder: (_, __) => const StandaloneMenuScreen(),
        routes: [
          GoRoute(
            path: 'equipment',
            builder: (_, __) => const EquipmentDetailScreen(),
          ),
          GoRoute(
            path: 'sostituzione-barcode',
            builder: (_, __) => const SostituzioneBarcodeScreen(),
          ),
          GoRoute(
            path: 'squadra',
            builder: (_, __) => const SquadraScreen(),
          ),
          GoRoute(
            path: 'templates',
            builder: (_, __) => const TemplatesScreen(),
          ),
        ],
      ),
      GoRoute(
          path: AppRoutes.createOrder,
          builder: (_, __) => const CreateOrderScreen()),
      GoRoute(
          path: AppRoutes.settings,
          builder: (_, __) => const SettingsScreen()),
      GoRoute(
          path: AppRoutes.syncQueue,
          builder: (_, __) => const SyncQueueScreen()),
      GoRoute(
          path: AppRoutes.notifications,
          builder: (_, __) => const NotificationsScreen()),
      GoRoute(
          path: AppRoutes.map,
          builder: (_, __) => const MapScreen()),
      GoRoute(
          path: AppRoutes.scanner,
          builder: (_, __) => const BarcodeScannerScreen()),
      GoRoute(
          path: AppRoutes.signature,
          builder: (_, __) => const SignatureScreen()),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Pagina non trovata: ${state.uri}')),
    ),
  );
});
