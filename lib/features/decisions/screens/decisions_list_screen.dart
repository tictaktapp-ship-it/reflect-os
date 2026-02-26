import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';

enum _SortOrder { newestFirst, oldestFirst, titleAsc, titleDesc }

class DecisionsListScreen extends ConsumerStatefulWidget {
  const DecisionsListScreen({super.key});

  @override
  ConsumerState<DecisionsListScreen> createState() =>
      _DecisionsListScreenState();
}

class _DecisionsListScreenState extends ConsumerState<DecisionsListScreen> {
  String? _selectedState;   // null = All
  String? _selectedStakes;  // null = All
  _SortOrder _sortOrder = _SortOrder.newestFirst;

  bool get _filtersActive => _selectedState != null || _selectedStakes != null;

  List<Decision> _applyFiltersAndSort(List<Decision> all) {
    var result = all.where((d) {
      if (_selectedState != null && d.state != _selectedState) return false;
      if (_selectedStakes != null) {
        if (d.stakes == null) return false;
        if (d.stakes!.toLowerCase() != _selectedStakes!.toLowerCase()) {
          return false;
        }
      }
      return true;
    }).toList();

    switch (_sortOrder) {
      case _SortOrder.newestFirst:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _SortOrder.oldestFirst:
        result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _SortOrder.titleAsc:
        result.sort((a, b) => a.title.compareTo(b.title));
      case _SortOrder.titleDesc:
        result.sort((a, b) => b.title.compareTo(a.title));
    }

    return result;
  }

  String _sortLabel(_SortOrder o) => switch (o) {
        _SortOrder.newestFirst => 'Newest first',
        _SortOrder.oldestFirst => 'Oldest first',
        _SortOrder.titleAsc => 'A → Z',
        _SortOrder.titleDesc => 'Z → A',
      };

  // ── CSV helpers ──────────────────────────────────────────────────────────────

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

  static String _toCsv(List<Decision> decisions) {
    final buf = StringBuffer();
    buf.writeln(
        'Title,State,Stakes,Category,Initial Confidence,Visibility,Created,Updated');
    for (final d in decisions) {
      buf.writeln([
        _csvField(d.title),
        _csvField(d.state),
        _csvField(d.stakes),
        _csvField(d.categoryName),
        _csvField(d.initialConfidence?.toString()),
        '', // Visibility — not present in current model
        _csvField(_isoDate(d.createdAt)),
        _csvField(_isoDate(d.updatedAt)),
      ].join(','));
    }
    return buf.toString();
  }

  void _downloadCsv(List<Decision> decisions) {
    final csv = _toCsv(decisions);
    // utf-8 BOM so Excel opens it correctly
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(csv)];
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute(
          'download',
          'decisions_${DateTime.now().millisecondsSinceEpoch}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported ${decisions.length} decisions')),
    );
  }

  // ── Sheets ───────────────────────────────────────────────────────────────────

  void _showSortSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: SvgPicture.asset(isDark ? 'assets/images/reflect-icon-dark.svg' : 'assets/images/reflect-icon-light.svg', height: 16)),
                const SizedBox(height: 8),
                Text(
                  'Sort by',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          RadioGroup<_SortOrder>(
            groupValue: _sortOrder,
            onChanged: (v) {
              if (v != null) {
                setState(() => _sortOrder = v);
                Navigator.of(context).pop();
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _SortOrder.values
                  .map((o) => RadioListTile<_SortOrder>(
                        title: Text(_sortLabel(o)),
                        value: o,
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showExportSheet(List<Decision> all, List<Decision> filtered) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: SvgPicture.asset(isDark ? 'assets/images/reflect-icon-dark.svg' : 'assets/images/reflect-icon-light.svg', height: 16)),
            const SizedBox(height: 8),
            Text(
              'Export Decisions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Export your decisions as a CSV file',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => _downloadCsv(all),
              child: Text('Export All (${all.length})'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed:
                  _filtersActive ? () => _downloadCsv(filtered) : null,
              child: Text('Export Filtered (${filtered.length})'),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Tooltip(
              message: 'Select a decision to generate a brief',
              child: FilledButton.tonal(
                onPressed: null,
                child: const Text('Export Brief (all decisions)'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter bar ───────────────────────────────────────────────────────────────

  Widget _filterBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── State row ────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
          child: Row(
            children: [
              for (final label in <String?>[
                null,
                'Draft',
                'Active',
                'Closed',
                'Archived',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(label ?? 'All'),
                    selected: _selectedState == label,
                    onSelected: (_) =>
                        setState(() => _selectedState = label),
                  ),
                ),
            ],
          ),
        ),
        // ── Stakes row ───────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
          child: Row(
            children: [
              for (final label in <String?>[
                null,
                'Low',
                'Medium',
                'High',
                'Critical',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(label ?? 'All'),
                    selected: _selectedStakes == label,
                    onSelected: (_) =>
                        setState(() => _selectedStakes = label),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final decisionsAsync = ref.watch(decisionsProvider);

    final allDecisions = decisionsAsync.valueOrNull ?? [];
    final filtered = _applyFiltersAndSort(allDecisions);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _filtersActive ? 'Decisions (${filtered.length})' : 'Decisions',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export CSV',
            onPressed: allDecisions.isEmpty
                ? null
                : () => _showExportSheet(allDecisions, filtered),
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onPressed: _showSortSheet,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: () => context.push(Routes.notifications),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/decisions/create'),
        tooltip: 'New decision',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _filterBar(),
          Expanded(
            child: decisionsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Failed to load decisions: $error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (_) {
                if (allDecisions.isEmpty) {
                  return const Center(child: Text('No decisions yet.'));
                }
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No decisions match the current filters.'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) =>
                      _DecisionTile(decision: filtered[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Decision tile ──────────────────────────────────────────────────────────────

class _DecisionTile extends StatelessWidget {
  const _DecisionTile({required this.decision});
  final Decision decision;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => context.push('/decisions/detail/${decision.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  decision.title,
                  style: Theme.of(context).textTheme.bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              _StatusBadge(status: decision.state),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status badge ───────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  Color _backgroundFor(String status) => switch (status.toLowerCase()) {
        'active' => AppColors.accentPrimary.withValues(alpha: 0.2),
        'draft' => AppColors.textMuted.withValues(alpha: 0.2),
        'closed' => AppColors.success.withValues(alpha: 0.2),
        'archived' => AppColors.textMuted.withValues(alpha: 0.15),
        _ => AppColors.textMuted.withValues(alpha: 0.2),
      };

  Color _foregroundFor(String status) => switch (status.toLowerCase()) {
        'active' => AppColors.accentHover,
        'draft' => AppColors.textSecondary,
        'closed' => AppColors.success,
        'archived' => AppColors.textMuted,
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _backgroundFor(status),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _foregroundFor(status),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
