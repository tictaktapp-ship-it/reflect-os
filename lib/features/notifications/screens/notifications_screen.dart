import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/features/notifications/data/models/notification_item.dart';
import 'package:reflect_os/features/notifications/providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SvgPicture.asset(
              Theme.of(context).brightness == Brightness.dark
                  ? 'assets/images/reflect-icon-dark.svg'
                  : 'assets/images/reflect-icon-light.svg',
              height: 40,
            ),
            const SizedBox(width: 8),
            const Text('Notifications'),
          ],
        ),
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load: $e', textAlign: TextAlign.center),
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_outlined,
                      size: 48, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text(
                    'No notifications',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = notifications[index];
              return _NotificationTile(
                key: ValueKey(item.id),
                item: item,
                onDismissed: () async {
                  await ref
                      .read(notificationsRepositoryProvider)
                      .dismissNotification(item.id);
                  ref.invalidate(notificationsProvider);
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ── Notification tile ──────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    super.key,
    required this.item,
    required this.onDismissed,
  });

  final NotificationItem item;
  final VoidCallback onDismissed;

  static final _dateFmt = DateFormat('d MMM yyyy');

  String _formatType(String type) {
    return type
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  ({Color background, Color foreground}) _colorsForStatus(String status) =>
      switch (status.toLowerCase()) {
        'pending' => (
            background: AppColors.warning.withValues(alpha: 0.2),
            foreground: AppColors.warning,
          ),
        'sent' => (
            background: AppColors.success.withValues(alpha: 0.2),
            foreground: AppColors.success,
          ),
        'failed' => (
            background: AppColors.destructive.withValues(alpha: 0.2),
            foreground: AppColors.destructive,
          ),
        _ => (
            background: AppColors.textMuted.withValues(alpha: 0.15),
            foreground: AppColors.textMuted,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final colors = _colorsForStatus(item.status);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.destructive.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.cancel_outlined, color: AppColors.destructive),
      ),
      onDismissed: (_) => onDismissed(),
      child: Card(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatType(item.type),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (item.relatedEntityType != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatType(item.relatedEntityType!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _dateFmt.format(item.scheduledFor.toLocal()),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.status,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
