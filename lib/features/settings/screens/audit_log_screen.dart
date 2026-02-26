import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/features/decisions/data/models/audit_event.dart';
import 'package:reflect_os/features/settings/providers/settings_provider.dart';

final _dateFmt = DateFormat('d MMM yyyy');
final _timeFmt = DateFormat('HH:mm');

String _formatEventType(String eventType) => switch (eventType) {
      'decision_created' => 'Decision created',
      'decision_updated' => 'Decision updated',
      'decision_deleted' => 'Decision deleted',
      'decision_archived' => 'Decision archived',
      'decision_state_changed' => 'Decision state changed',
      'outcome_update_created' => 'Outcome recorded',
      'outcome_update_updated' => 'Outcome updated',
      'outcome_update_deleted' => 'Outcome deleted',
      'checkpoint_created' => 'Checkpoint created',
      'checkpoint_updated' => 'Checkpoint updated',
      'checkpoint_completed' => 'Checkpoint completed',
      'checkpoint_deleted' => 'Checkpoint deleted',
      'stakeholder_added' => 'Stakeholder added',
      'stakeholder_removed' => 'Stakeholder removed',
      'member_invited' => 'Member invited',
      'member_removed' => 'Member removed',
      'evidence_added' => 'Evidence added',
      'evidence_deleted' => 'Evidence deleted',
      _ => eventType
          .split('_')
          .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' '),
    };

String _truncateId(String? id) {
  if (id == null) return '—';
  return id.length > 8 ? id.substring(0, 8) : id;
}

String _localDateKey(DateTime dt) {
  final local = dt.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditAsync = ref.watch(auditLogProvider);

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
            const Text('Audit Log'),
          ],
        ),
      ),
      body: auditAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load audit log: $e',
                textAlign: TextAlign.center),
          ),
        ),
        data: (events) {
          if (events.isEmpty) {
            return Center(
              child: Text(
                'No audit events recorded.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textMuted),
              ),
            );
          }

          // Build list items with date headers injected between date groups.
          final items = <_ListItem>[];
          String? lastDateKey;
          for (final event in events) {
            final dateKey = _localDateKey(event.createdAt);
            if (dateKey != lastDateKey) {
              items.add(_DateHeader(event.createdAt.toLocal()));
              lastDateKey = dateKey;
            }
            items.add(_EventRow(event));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            itemBuilder: (_, index) {
              final item = items[index];
              if (item is _DateHeader) {
                return _DateHeaderWidget(date: item.date);
              } else {
                return _EventRowWidget(event: (item as _EventRow).event);
              }
            },
          );
        },
      ),
    );
  }
}

// ── List item sealed types ────────────────────────────────────────────────────

sealed class _ListItem {}

class _DateHeader extends _ListItem {
  _DateHeader(this.date);
  final DateTime date;
}

class _EventRow extends _ListItem {
  _EventRow(this.event);
  final AuditEvent event;
}

// ── Date header widget ────────────────────────────────────────────────────────

class _DateHeaderWidget extends StatelessWidget {
  const _DateHeaderWidget({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        _dateFmt.format(date),
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

// ── Event row widget ──────────────────────────────────────────────────────────

class _EventRowWidget extends StatelessWidget {
  const _EventRowWidget({required this.event});
  final AuditEvent event;

  @override
  Widget build(BuildContext context) {
    final transition = event.metadataJsonb['transition'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time
          SizedBox(
            width: 40,
            child: Text(
              _timeFmt.format(event.createdAt.toLocal()),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatEventType(event.eventType),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _truncateId(event.subjectEntityId),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textMuted,
                            fontFamily: 'monospace',
                          ),
                    ),
                    if (transition != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.accentPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          transition,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.accentHover,
                                  ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
