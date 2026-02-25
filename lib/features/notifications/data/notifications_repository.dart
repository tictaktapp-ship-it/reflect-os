import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/notifications/data/models/notification_item.dart';

class NotificationsRepository {
  const NotificationsRepository();

  Future<List<NotificationItem>> getNotifications() async {
    final rows = await supabase
        .from('user_visible_notifications')
        .select()
        .order('scheduled_for', ascending: false);

    return rows.map((row) => NotificationItem.fromJson(row)).toList();
  }

  /// Exception to the no-raw-tables rule: no RPC exists for dismissing
  /// notifications. Updates notification_queue directly.
  Future<void> dismissNotification(String id) async {
    await supabase
        .from('notification_queue')
        .update({'status': 'Cancelled'})
        .eq('id', id);
  }
}
