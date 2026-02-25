import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/features/notifications/data/notifications_repository.dart';
import 'package:reflect_os/features/notifications/data/models/notification_item.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => const NotificationsRepository(),
);

final notificationsProvider = FutureProvider<List<NotificationItem>>((ref) {
  return ref.read(notificationsRepositoryProvider).getNotifications();
});
