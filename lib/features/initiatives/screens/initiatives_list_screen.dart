import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/utils/csv_downloader.dart';
import 'package:reflect_os/widgets/app_header.dart';
import 'package:reflect_os/features/initiatives/data/models/initiative.dart';
import 'package:reflect_os/features/initiatives/providers/initiatives_provider.dart';

class InitiativesListScreen extends ConsumerWidget {
  const InitiativesListScreen({super.key});

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

  static String _toCsv(List<Initiative> initiatives) {
    final buf = StringBuffer();
    buf.writeln('Name,Description,Created Date');
    for (final i in initiatives) {
      buf.writeln([
        _csvField(i.name),
        _csvField(i.descriptionEncrypted),
        _csvField(_isoDate(i.createdAt)),
      ].join(','));
    }
    return buf.toString();
  }

  static void _downloadCsv(BuildContext context, List<Initiative> initiatives) {
    final csv = _toCsv(initiatives);
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(csv)];
    downloadCsv(
        bytes, 'initiatives_${DateTime.now().millisecondsSinceEpoch}.csv');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported ${initiatives.length} initiatives')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initiativesAsync = ref.watch(initiativesProvider);
    final initiatives = initiativesAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppHeader(
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export CSV',
            onPressed: initiatives.isEmpty
                ? null
                : () => _downloadCsv(context, initiatives),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accentPrimary,
        foregroundColor: Colors.white,
        onPressed: () => context.push(Routes.initiativesCreate),
        child: const Icon(Icons.add),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Group related decisions into strategic initiatives to track progress at a higher level.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ),
          Expanded(
            child: initiativesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Failed to load: $e', textAlign: TextAlign.center),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No initiatives yet.\nTap + to create one.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _InitiativeTile(initiative: items[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InitiativeTile extends StatelessWidget {
  const _InitiativeTile({required this.initiative});

  final Initiative initiative;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => context.push(
          '/initiatives/detail/${initiative.id}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                initiative.name,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (initiative.descriptionEncrypted != null &&
                  initiative.descriptionEncrypted!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  initiative.descriptionEncrypted!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
