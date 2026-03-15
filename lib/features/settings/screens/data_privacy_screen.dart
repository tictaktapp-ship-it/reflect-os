import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/widgets/dialog_shell.dart';
import 'package:reflect_os/core/utils/csv_downloader.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';
import 'package:reflect_os/features/settings/data/models/gdpr_request.dart';
import 'package:reflect_os/features/settings/providers/settings_provider.dart';

class DataPrivacyScreen extends ConsumerStatefulWidget {
  const DataPrivacyScreen({super.key});

  @override
  ConsumerState<DataPrivacyScreen> createState() => _DataPrivacyScreenState();
}

class _DataPrivacyScreenState extends ConsumerState<DataPrivacyScreen> {
  bool _isSubmitting = false;

  // ── CSV helpers ────────────────────────────────────────────────────────────

  static String _csvField(String? value) {
    if (value == null || value.isEmpty) return '';
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String _isoDate(DateTime dt) =>
      dt.toLocal().toIso8601String().split('T').first;

  void _downloadDecisionsCsv() async {
    final decisions = await ref.read(decisionsProvider.future);
    if (!mounted) return;

    final buf = StringBuffer();
    buf.writeln(
        'Title,State,Stakes,Category,Initial Confidence,Created,Updated');
    for (final d in decisions) {
      buf.writeln([
        _csvField(d.title),
        _csvField(d.state),
        _csvField(d.stakes),
        _csvField(d.categoryName),
        _csvField(d.initialConfidence?.toString()),
        _csvField(_isoDate(d.createdAt)),
        _csvField(_isoDate(d.updatedAt)),
      ].join(','));
    }

    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(buf.toString())];
    downloadCsv(bytes, 'decisions_${DateTime.now().millisecondsSinceEpoch}.csv');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported ${decisions.length} decisions')),
      );
    }
  }

  // ── Export request ─────────────────────────────────────────────────────────

  Future<void> _submitExportRequest() async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(settingsRepositoryProvider).createExportRequest();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Export request submitted — you\'ll receive an email when ready'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit request: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Deletion request ───────────────────────────────────────────────────────

  void _showDeletionSheet() {
    final reasonCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DialogShell(
        title: 'Delete Account',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your personal decisions will be deleted after a 30-day grace period. '
              'Team decisions will be anonymised immediately.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: reasonCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => _isSubmitting = true);
              try {
                await ref
                    .read(settingsRepositoryProvider)
                    .createDeletionRequest(reasonCtrl.text.trim());
                ref.invalidate(gdprRequestsProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Deletion request submitted. You have 30 days to cancel.'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Failed to submit request: $e')),
                  );
                }
              } finally {
                if (mounted) setState(() => _isSubmitting = false);
              }
            },
            child: const Text('Request Deletion'),
          ),
        ],
      ),
    );
  }

  // ── Cancel GDPR request ────────────────────────────────────────────────────

  Future<void> _cancelRequest(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogShell(
        title: 'Cancel Request',
        child: const Text('Are you sure you want to cancel this GDPR request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, cancel it'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(settingsRepositoryProvider).cancelGdprRequest(requestId);
      ref.invalidate(gdprRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request cancelled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel request: $e')),
        );
      }
    }
  }

  // ── Restore decision ───────────────────────────────────────────────────────

  Future<void> _restoreDecision(String id, String title) async {
    try {
      await ref.read(settingsRepositoryProvider).restoreDecision(id);
      ref.invalidate(recentlyDeletedDecisionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$title" restored')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gdprAsync = ref.watch(gdprRequestsProvider);
    final deletedAsync = ref.watch(recentlyDeletedDecisionsProvider);

    final activeRequests = gdprAsync.valueOrNull
            ?.where((r) => r.status == 'Pending' || r.status == 'Processing')
            .toList() ??
        [];

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Your Data ───────────────────────────────────────────────────
          _SectionLabel(label: 'Your Data'),
          Card(
            color: Theme.of(context).colorScheme.surface,
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Export my data'),
                  subtitle: const Text(
                      'Request a full export of your data via email'),
                  trailing: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _isSubmitting ? null : _submitExportRequest,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined),
                  title: const Text('Download decisions as CSV'),
                  subtitle: const Text('Download all your decisions as a CSV file'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _downloadDecisionsCsv,
                ),
              ],
            ),
          ),

          // ── Active Requests ─────────────────────────────────────────────
          if (activeRequests.isNotEmpty) ...[
            _SectionLabel(label: 'Active Requests'),
            Card(
              color: Theme.of(context).colorScheme.surface,
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: activeRequests
                    .map(
                      (r) => _GdprRequestTile(
                        request: r,
                        onCancel: r.isCancellable
                            ? () => _cancelRequest(r.id)
                            : null,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],

          // ── Recently Deleted ────────────────────────────────────────────
          _SectionLabel(label: 'Recently Deleted'),
          Card(
            color: Theme.of(context).colorScheme.surface,
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deleted decisions are recoverable for 30 days.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                  const SizedBox(height: 12),
                  deletedAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) =>
                        Text('Failed to load: $err'),
                    data: (deleted) {
                      if (deleted.isEmpty) {
                        return Text(
                          'No recently deleted decisions.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.4),
                                  ),
                        );
                      }
                      return Column(
                        children: deleted
                            .map((d) => _DeletedDecisionTile(
                                  id: d['id'] as String,
                                  title: d['title'] as String,
                                  deletedAt: DateTime.parse(
                                      d['deleted_at'] as String),
                                  onRestore: () => _restoreDecision(
                                      d['id'] as String,
                                      d['title'] as String),
                                ))
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── Delete Account ──────────────────────────────────────────────
          _SectionLabel(label: 'Delete Account'),
          Card(
            color: AppColors.destructive.withValues(alpha: 0.04),
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                  color: AppColors.destructive.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Personal decisions will be permanently deleted. '
                    'Decisions shared to team workspaces will be anonymised — '
                    'your name replaced with \'Former member\'.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.destructive,
                      side: const BorderSide(color: AppColors.destructive),
                    ),
                    onPressed: _isSubmitting ? null : _showDeletionSheet,
                    child: const Text('Request account deletion'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── GDPR request tile ──────────────────────────────────────────────────────────

class _GdprRequestTile extends StatelessWidget {
  const _GdprRequestTile({required this.request, this.onCancel});

  final GdprRequest request;
  final VoidCallback? onCancel;

  Color _statusColor(String status) => switch (status) {
        'Pending' => AppColors.warning,
        'Processing' => AppColors.accentPrimary,
        'Complete' => AppColors.success,
        'Cancelled' => AppColors.textMuted,
        _ => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TypeBadge(type: request.requestType),
                    const SizedBox(width: 6),
                    _StatusBadge(
                        status: request.status,
                        color: _statusColor(request.status)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('d MMM yyyy').format(request.createdAt.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                ),
              ],
            ),
          ),
          if (onCancel != null)
            TextButton(
              onPressed: onCancel,
              style:
                  TextButton.styleFrom(foregroundColor: AppColors.destructive),
              child: const Text('Cancel'),
            ),
        ],
      ),
    );
  }
}

// ── Deleted decision tile ──────────────────────────────────────────────────────

class _DeletedDecisionTile extends StatelessWidget {
  const _DeletedDecisionTile({
    required this.id,
    required this.title,
    required this.deletedAt,
    required this.onRestore,
  });

  final String id;
  final String title;
  final DateTime deletedAt;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Deleted ${DateFormat('d MMM yyyy').format(deletedAt.toLocal())}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRestore,
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }
}

// ── Badge widgets ──────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final String type;

  String _label(String t) => switch (t) {
        'deletion' => 'Deletion',
        'export' => 'Export',
        'anonymisation' => 'Anonymisation',
        _ => t,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _label(type),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6, top: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
      ),
    );
  }
}
