// Notifica in-app (ODL assegnato, avviso, sync…).

enum AppNotificationType {
  nuovoOdl,
  odlModificato,
  odlRevocato,
  nuovoAvviso,
  sincronizzazione,
  promemoria;

  String get label => switch (this) {
        AppNotificationType.nuovoOdl => 'Nuovo OdL',
        AppNotificationType.odlModificato => 'OdL modificato',
        AppNotificationType.odlRevocato => 'OdL revocato',
        AppNotificationType.nuovoAvviso => 'Nuovo avviso',
        AppNotificationType.sincronizzazione => 'Sincronizzazione',
        AppNotificationType.promemoria => 'Promemoria',
      };
}

class AppNotification {
  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final String? relatedId;  // workOrderCode o numeroAvviso
  final String? routePath;  // percorso go_router per navigazione al tocco
  final DateTime receivedAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.relatedId,
    this.routePath,
    required this.receivedAt,
    this.isRead = false,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        relatedId: relatedId,
        routePath: routePath,
        receivedAt: receivedAt,
        isRead: isRead ?? this.isRead,
      );
}
