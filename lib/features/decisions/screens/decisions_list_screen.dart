import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/utils/csv_downloader.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';
import 'package:reflect_os/widgets/app_header.dart';
import 'package:reflect_os/widgets/dialog_shell.dart';

final _dateFmt = DateFormat('d MMM');

enum _SortOrder { newestFirst, oldestFirst, titleAsc, titleDesc }

const _stateOrder = ['Active', 'Draft', 'Closed', 'Archived'];

class DecisionsListScreen extends ConsumerStatefulWidget {
  const DecisionsListScreen({super.key});

  @override
  ConsumerState<DecisionsListScreen> createState() =>
      _DecisionsListScreenState();
}

class _DecisionsListScreenState extends ConsumerState<DecisionsListScreen> {
  String? _selectedState;
  String? _selectedStakes;
  _SortOrder _sortOrder = _SortOrder.newestFirst;

  bool get _filtersActive => _selectedState != null || _selectedStakes != null;

  List<Decision> _applySort(List<Decision> list) {
    final result = [...list];
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

  List<Decision> _applyFilters(List<Decision> all) {
    return all.where((d) {
      if (_selectedState != null && d.state != _selectedState) return false;
      if (_selectedStakes != null) {
        if (d.stakes == null) return false;
        if (d.stakes!.toLowerCase() != _selectedStakes!.toLowerCase()) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  String _sortLabel(_SortOrder o) => switch (o) {
        _SortOrder.newestFirst => 'Newest first',
        _SortOrder.oldestFirst => 'Oldest first',
        _SortOrder.titleAsc => 'A → Z',
        _SortOrder.titleDesc => 'Z → A',
      };

  // ── CSV export ───────────────────────────────────────────────────────────────

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
        'Title,State,Stakes,Category,Initial Confidence,Created Date,Last Updated');
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
    return buf.toString();
  }

  void _downloadCsv(List<Decision> decisions) {
    final csv = _toCsv(decisions);
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(csv)];
    downloadCsv(bytes, 'decisions_${DateTime.now().millisecondsSinceEpoch}.csv');
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported ${decisions.length} decisions')),
    );
  }

  // ── Actions dialog ───────────────────────────────────────────────────────────

  void _showActionsDialog(List<Decision> all, List<Decision> sorted) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DialogShell(
        title: 'Actions',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionRow(
              icon: Icons.mic_outlined,
              label: 'Capture from meeting',
              onTap: () {
                Navigator.of(ctx).pop();
                context.push(Routes.decisionsMeetingCapture);
              },
            ),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            _ActionRow(
              icon: Icons.sort_outlined,
              label: 'Sort decisions',
              onTap: () {
                Navigator.of(ctx).pop();
                _showTuneSheet(all, sorted);
              },
            ),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            _ActionRow(
              icon: Icons.filter_list_outlined,
              label: 'Filter decisions',
              onTap: () {
                Navigator.of(ctx).pop();
                _showTuneSheet(all, sorted);
              },
            ),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            _ActionRow(
              icon: Icons.download_outlined,
              label: 'Export',
              onTap: () {
                Navigator.of(ctx).pop();
                _showTuneSheet(all, sorted);
              },
            ),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            _ActionRow(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              onTap: () {
                Navigator.of(ctx).pop();
                context.push(Routes.notifications);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Tune sheet (filter + sort + export) ─────────────────────────────────────

  void _showTuneSheet(List<Decision> all, List<Decision> filtered) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: Color(0xFF19CBD6), width: 1.5),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void updateFilter(VoidCallback fn) {
            setState(fn);
            setSheetState(fn);
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: SvgPicture.asset('assets/branding/icon.svg',
                        height: 36),
                  ),
                  const SizedBox(height: 16),

                  // ── Sort ──────────────────────────────────────────────────
                  Text('SORT',
                      style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                            color: Theme.of(ctx)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                            letterSpacing: 0.8,
                          )),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _SortOrder.values
                        .map((o) => ChoiceChip(
                              label: Text(_sortLabel(o)),
                              selected: _sortOrder == o,
                              onSelected: (_) =>
                                  updateFilter(() => _sortOrder = o),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── Filter by status ──────────────────────────────────────
                  Row(
                    children: [
                      Text('STATUS',
                          style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                                letterSpacing: 0.8,
                              )),
                      const Spacer(),
                      if (_filtersActive)
                        TextButton(
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap),
                          onPressed: () => updateFilter(() {
                            _selectedState = null;
                            _selectedStakes = null;
                          }),
                          child: const Text('Clear all'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <String?>[
                      null,
                      'Draft',
                      'Active',
                      'Closed',
                      'Archived'
                    ]
                        .map((s) => FilterChip(
                              label: Text(s ?? 'All'),
                              selected: _selectedState == s,
                              onSelected: (_) =>
                                  updateFilter(() => _selectedState = s),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── Filter by priority ────────────────────────────────────
                  Text('PRIORITY',
                      style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                            color: Theme.of(ctx)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                            letterSpacing: 0.8,
                          )),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <String?>[
                      null,
                      'Low',
                      'Medium',
                      'High',
                      'Critical'
                    ]
                        .map((s) => FilterChip(
                              label: Text(s ?? 'All'),
                              selected: _selectedStakes == s,
                              onSelected: (_) =>
                                  updateFilter(() => _selectedStakes = s),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 8),

                  // ── Export ────────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.download_outlined, size: 16),
                          label: Text('Export all (${all.length})'),
                          onPressed:
                              all.isEmpty ? null : () => _downloadCsv(all),
                        ),
                      ),
                      if (_filtersActive) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.filter_list, size: 16),
                            label: Text('Export filtered (${filtered.length})'),
                            onPressed: filtered.isEmpty
                                ? null
                                : () => _downloadCsv(filtered),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final decisionsAsync = ref.watch(decisionsProvider);
    final allDecisions = decisionsAsync.valueOrNull ?? [];
    final filtered = _applyFilters(allDecisions);
    final sorted = _applySort(filtered);

    return Scaffold(
      appBar: AppHeader(
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Actions',
            onPressed: () => _showActionsDialog(allDecisions, sorted),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accentPrimary,
        foregroundColor: Colors.white,
        onPressed: () => context.push(Routes.decisionsCreate),
        icon: const Icon(Icons.add),
        label: const Text('New Decision'),
      ),
      body: decisionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
          if (sorted.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No decisions match the current filters.'),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedState = null;
                      _selectedStakes = null;
                    }),
                    child: const Text('Clear filters'),
                  ),
                ],
              ),
            );
          }

          // Group by state in canonical order.
          final groups = <String, List<Decision>>{};
          for (final state in _stateOrder) {
            final inGroup =
                sorted.where((d) => d.state == state).toList();
            if (inGroup.isNotEmpty) groups[state] = inGroup;
          }
          // Any unexpected state
          final other = sorted
              .where((d) => !_stateOrder.contains(d.state))
              .toList();
          if (other.isNotEmpty) groups['Other'] = other;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              for (final entry in groups.entries)
                _DecisionGroup(
                  state: entry.key,
                  decisions: entry.value,
                  initiallyExpanded: entry.key == 'Active',
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Decision group (collapsible deck-of-cards) ────────────────────────────────

class _DecisionGroup extends StatefulWidget {
  const _DecisionGroup({
    required this.state,
    required this.decisions,
    this.initiallyExpanded = false,
  });

  final String state;
  final List<Decision> decisions;
  final bool initiallyExpanded;

  @override
  State<_DecisionGroup> createState() => _DecisionGroupState();
}

class _DecisionGroupState extends State<_DecisionGroup> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Group header ────────────────────────────────────────────────────
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  _StateGroupDot(state: widget.state),
                  const SizedBox(width: 8),
                  Text(
                    widget.state.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF19CBD6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.decisions.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content (fan deck or expanded grid) ─────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        final w = constraints.maxWidth;
                        final cols = w > 1100 ? 4 : w > 700 ? 3 : 2;
                        const gap = 12.0;
                        final cardWidth = (w - gap * (cols - 1)) / cols;
                        final cardHeight = cardWidth / 0.72;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: widget.decisions
                              .map((d) => SizedBox(
                                    width: cardWidth,
                                    height: cardHeight,
                                    child: _PortraitCard(decision: d),
                                  ))
                              .toList(),
                        );
                      },
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: _FanDeck(decisions: widget.decisions),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StateGroupDot extends StatelessWidget {
  const _StateGroupDot({required this.state});
  final String state;

  Color _colorFor(String s) => switch (s.toLowerCase()) {
        'active' => AppColors.accentPrimary,
        'draft' => AppColors.textSecondary,
        'closed' => AppColors.success,
        'archived' => AppColors.textMuted,
        _ => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _colorFor(state),
        shape: BoxShape.circle,
      ),
    );
  }
}

// ── Portrait card ─────────────────────────────────────────────────────────────

class _PortraitCard extends StatefulWidget {
  const _PortraitCard({required this.decision});
  final Decision decision;

  @override
  State<_PortraitCard> createState() => _PortraitCardState();
}

class _PortraitCardState extends State<_PortraitCard> {
  bool _hovered = false;

  static Color _healthColor(String? h) => switch (h) {
        'on_track' => const Color(0xFF2EA073),
        'needs_attention' => const Color(0xFFD97D24),
        'overdue' => const Color(0xFFDC4444),
        _ => const Color(0xFF94A3B8),
      };

  @override
  Widget build(BuildContext context) {
    final d = widget.decision;
    final health = d.healthState;
    final hasCategory = d.categoryName?.isNotEmpty == true;
    final hasStakes = d.stakes?.isNotEmpty == true;
    final hasConfidence = d.initialConfidence != null;
    final hasDeadline = d.decisionDeadline != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              blurRadius: _hovered ? 10 : 6,
              offset: const Offset(0, 3),
              color: Colors.black12,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push('/decisions/detail/${d.id}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top row: health dot + state badge ──────────────────────
                  Row(
                    children: [
                      if (health != null) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _healthColor(health),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      const Spacer(),
                      _StateBadge(state: d.state),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // ── Title ───────────────────────────────────────────────────
                  Text(
                    d.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // ── Category + stakes ────────────────────────────────────
                  if (hasCategory)
                    Row(
                      children: [
                        const Icon(Icons.label_outline,
                            size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            d.categoryName!,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (hasStakes) ...[
                    if (hasCategory) const SizedBox(height: 2),
                    Text(
                      d.stakes!,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],

                  const Spacer(),

                  // ── Bottom: divider + confidence + deadline ───────────────
                  const Divider(
                      color: Color(0xFFE2E8F0), height: 1, thickness: 1),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (hasConfidence)
                        Text(
                          '${d.initialConfidence}/10',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF19CBD6),
                          ),
                        ),
                      const Spacer(),
                      if (hasDeadline)
                        Text(
                          'Due ${_dateFmt.format(d.decisionDeadline!)}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state});
  final String state;

  Color _bg(String s) => switch (s.toLowerCase()) {
        'active' => AppColors.accentPrimary.withValues(alpha: 0.12),
        'draft' => AppColors.textMuted.withValues(alpha: 0.12),
        'closed' => AppColors.success.withValues(alpha: 0.15),
        'archived' => AppColors.textMuted.withValues(alpha: 0.10),
        _ => AppColors.textMuted.withValues(alpha: 0.12),
      };

  Color _fg(String s) => switch (s.toLowerCase()) {
        'active' => AppColors.accentPrimary,
        'draft' => AppColors.textSecondary,
        'closed' => AppColors.success,
        'archived' => AppColors.textMuted,
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _bg(state),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        state,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _fg(state),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ── Fan deck (collapsed group — physical card spread) ────────────────────────

class _FanDeck extends StatelessWidget {
  const _FanDeck({required this.decisions});
  final List<Decision> decisions;

  static const double _cardH = 160.0;
  static const List<double> _rotations = [0.0, 0.04, 0.08, 0.12];
  static const List<double> _translateX = [0.0, 18.0, 36.0, 54.0];
  static const List<double> _translateY = [0.0, 6.0, 12.0, 18.0];
  static const List<double> _opacities = [1.0, 0.90, 0.75, 0.60];

  @override
  Widget build(BuildContext context) {
    if (decisions.isEmpty) return const SizedBox.shrink();
    final count = decisions.length.clamp(1, 4);

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final cardW = constraints.maxWidth;
        return SizedBox(
          height: _cardH + 18,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Draw back cards first (highest index = furthest behind)
              for (int i = count - 1; i >= 0; i--)
                Positioned(
                  left: _translateX[i],
                  top: _translateY[i],
                  width: cardW,
                  height: _cardH,
                  child: Opacity(
                    opacity: _opacities[i],
                    child: Transform.rotate(
                      angle: _rotations[i],
                      alignment: Alignment.bottomCenter,
                      child: _PortraitCard(decision: decisions[i]),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Action row (inside Actions dialog) ───────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF19CBD6)),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
