import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/theme/app_radius.dart';
import 'package:reflect_os/features/decisions/widgets/quick_log_sheet.dart';
import 'package:reflect_os/features/notifications/data/models/notification_item.dart';
import 'package:reflect_os/features/notifications/providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(),
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
                      size: 48,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text(
                    'No notifications',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6)),
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

  // ── Type metadata ────────────────────────────────────────────────────────

  static const _kTeal = Color(0xFF19CBD6);

  ({IconData icon, Color color}) _iconForType(String type) =>
      switch (type) {
        'activation_habit' =>
          (icon: Icons.notifications_active_rounded, color: _kTeal),
        'activation_insight' =>
          (icon: Icons.lightbulb_outline_rounded, color: Color(0xFFF59E0B)),
        'activation_pattern' =>
          (icon: Icons.insights_rounded, color: Color(0xFF8B5CF6)),
        'activation_review' =>
          (icon: Icons.flag_outlined, color: Color(0xFFEF4444)),
        'activation_lockIn' =>
          (icon: Icons.auto_awesome_rounded, color: Color(0xFF3B82F6)),
        'activation_milestone' =>
          (icon: Icons.emoji_events_outlined, color: Color(0xFFF59E0B)),
        _ => (icon: Icons.notifications_outlined, color: _kTeal),
      };

  String _fallbackLabel(String type) => type
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

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

  // ── Navigation ───────────────────────────────────────────────────────────

  void _handleTap(BuildContext context) {
    final type = item.type;
    if (type == 'activation_habit' || type == 'activation_review') {
      _openQuickLog(context);
    } else if (type.startsWith('activation_')) {
      GoRouter.of(context).go(Routes.dashboard);
    }
    // Non-activation types: no-op tap (existing behaviour)
  }

  void _openQuickLog(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    if (isWide) {
      showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: const QuickLogSheet(),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.97,
          builder: (_, _) => ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: const QuickLogSheet(),
          ),
        ),
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = _colorsForStatus(item.status);
    final typeIcon = _iconForType(item.type);
    final isActivation = item.type.startsWith('activation_');
    final isTappable = item.type == 'activation_habit' ||
        item.type == 'activation_review' ||
        (isActivation &&
            item.type != 'activation_habit' &&
            item.type != 'activation_review');

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.destructive.withValues(alpha: 0.15),
          borderRadius: AppRadius.mdBR,
        ),
        child:
            const Icon(Icons.cancel_outlined, color: AppColors.destructive),
      ),
      onDismissed: (_) => onDismissed(),
      child: Card(
        color: Theme.of(context).colorScheme.surface,
        child: InkWell(
          borderRadius: AppRadius.mdBR,
          onTap: isTappable ? () => _handleTap(context) : null,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Type icon ──────────────────────────────────────────
                if (isActivation) ...[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: typeIcon.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(typeIcon.icon,
                        size: 18, color: typeIcon.color),
                  ),
                  const SizedBox(width: 12),
                ],

                // ── Content ────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title: use rich title if available, else type label
                      Text(
                        item.title ?? _fallbackLabel(item.type),
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      // Body: show if present
                      if (item.body != null && item.body!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.body!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.65),
                                height: 1.4,
                              ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else if (!isActivation &&
                          item.relatedEntityType != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _fallbackLabel(item.relatedEntityType!),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        _dateFmt.format(item.scheduledFor.toLocal()),
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.4),
                                ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // ── Status badge ───────────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.background,
                        borderRadius: AppRadius.mdBR,
                      ),
                      child: Text(
                        item.status,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              color: colors.foreground,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    if (isTappable) ...[
                      const SizedBox(height: 6),
                      Icon(Icons.chevron_right_rounded,
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.3)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
