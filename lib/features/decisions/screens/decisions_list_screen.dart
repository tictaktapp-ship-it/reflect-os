import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/core/utils/csv_downloader.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';
import 'package:reflect_os/widgets/app_header.dart';
import 'package:reflect_os/widgets/dialog_shell.dart';

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
            Divider(color: context.cs.borderDefault, height: 1),
            _ActionRow(
              icon: Icons.sort_outlined,
              label: 'Sort decisions',
              onTap: () {
                Navigator.of(ctx).pop();
                _showTuneSheet(all, sorted);
              },
            ),
            Divider(color: context.cs.borderDefault, height: 1),
            _ActionRow(
              icon: Icons.filter_list_outlined,
              label: 'Filter decisions',
              onTap: () {
                Navigator.of(ctx).pop();
                _showTuneSheet(all, sorted);
              },
            ),
            Divider(color: context.cs.borderDefault, height: 1),
            _ActionRow(
              icon: Icons.download_outlined,
              label: 'Export',
              onTap: () {
                Navigator.of(ctx).pop();
                _showTuneSheet(all, sorted);
              },
            ),
            Divider(color: context.cs.borderDefault, height: 1),
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
      backgroundColor: context.cs.backgroundSecondary,
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

// ── Card detail models ────────────────────────────────────────────────────────

class _ReviewCheckpointSummary {
  const _ReviewCheckpointSummary({
    required this.checkpointType,
    required this.dueAt,
    required this.status,
  });

  final String checkpointType;
  final DateTime dueAt;
  final String status;

  factory _ReviewCheckpointSummary.fromJson(Map<String, dynamic> json) =>
      _ReviewCheckpointSummary(
        checkpointType: json['checkpoint_type'] as String,
        dueAt: DateTime.parse(json['due_at'] as String),
        status: json['status'] as String,
      );
}

class _DecisionCardDetail {
  const _DecisionCardDetail({
    required this.tags,
    required this.checkpoints,
    required this.coachAdjustmentSum,
  });

  final List<String> tags;
  final List<_ReviewCheckpointSummary> checkpoints;
  final int coachAdjustmentSum;
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

enum _GroupView { fan, spread, detail }

class _DecisionGroupState extends State<_DecisionGroup> {
  late _GroupView _view;
  String? _activeDetailId;
  final Map<String, _DecisionCardDetail?> _detailCache = {};

  @override
  void initState() {
    super.initState();
    _view = widget.initiallyExpanded ? _GroupView.spread : _GroupView.fan;
  }

  void _openDetail(String decisionId) {
    setState(() {
      _view = _GroupView.detail;
      _activeDetailId = decisionId;
    });
    _fetchDetailIfNeeded(decisionId);
  }

  Future<void> _fetchDetailIfNeeded(String decisionId) async {
    if (_detailCache.containsKey(decisionId)) return;
    setState(() => _detailCache[decisionId] = null); // null = loading

    try {
      final results = await Future.wait([
        supabase
            .from('decision_tags')
            .select('tags(name)')
            .eq('decision_id', decisionId)
            .isFilter('deleted_at', null),
        supabase
            .from('review_checkpoints')
            .select('checkpoint_type, due_at, status')
            .eq('decision_id', decisionId)
            .isFilter('deleted_at', null)
            .order('due_at', ascending: true)
            .limit(3),
        supabase
            .from('coach_notes')
            .select('coach_confidence_adjustment')
            .eq('decision_id', decisionId)
            .isFilter('deleted_at', null)
            .not('coach_confidence_adjustment', 'is', null),
      ]);

      if (!mounted) return;

      final tagRows = results[0] as List<dynamic>;
      final checkpointRows = results[1] as List<dynamic>;
      final coachRows = results[2] as List<dynamic>;

      setState(() {
        _detailCache[decisionId] = _DecisionCardDetail(
          tags: tagRows
              .map((r) {
                final t = r['tags'];
                return t is Map ? t['name'] as String? : null;
              })
              .whereType<String>()
              .toList(),
          checkpoints: checkpointRows
              .map((r) =>
                  _ReviewCheckpointSummary.fromJson(r as Map<String, dynamic>))
              .toList(),
          coachAdjustmentSum: coachRows
              .map((r) => (r['coach_confidence_adjustment'] as num).toInt())
              .fold(0, (a, b) => a + b),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _detailCache[decisionId] = const _DecisionCardDetail(
          tags: [],
          checkpoints: [],
          coachAdjustmentSum: 0,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Group header ────────────────────────────────────────────────────
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              _view =
                  _view == _GroupView.fan ? _GroupView.spread : _GroupView.fan;
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  _StateGroupDot(state: widget.state),
                  const SizedBox(width: 8),
                  Text(
                    widget.state.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.cs.textSecondary,
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
                    turns: _view != _GroupView.fan ? 0.5 : 0.0,
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

          // ── Content ──────────────────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, top: 12, bottom: 16),
              child: switch (_view) {
                _GroupView.fan => _FanDeck(
                    decisions: widget.decisions,
                    onTapFront: _openDetail,
                    onExpandStack: () =>
                        setState(() => _view = _GroupView.spread),
                  ),
                _GroupView.spread => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final d in widget.decisions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _CollapsedCard(
                            decision: d,
                            onTap: () => _openDetail(d.id),
                          ),
                        ),
                    ],
                  ),
                _GroupView.detail => () {
                    final decision = widget.decisions.firstWhere(
                      (d) => d.id == _activeDetailId,
                      orElse: () => widget.decisions.first,
                    );
                    return _ExpandedCard(
                      decision: decision,
                      detail: _detailCache[_activeDetailId ?? ''],
                      onCollapse: () =>
                          setState(() => _view = _GroupView.spread),
                    );
                  }(),
              },
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

// ── Collapsed card (~80px horizontal, used in fan deck + spread list) ─────────

class _CollapsedCard extends StatelessWidget {
  const _CollapsedCard({
    required this.decision,
    this.onTap,
    this.fixedWidth,
    this.fixedHeight,
  });

  final Decision decision;
  final VoidCallback? onTap;
  final double? fixedWidth;
  final double? fixedHeight;

  static Color _healthColour(String? h) => switch (h) {
        'on_track' => const Color(0xFF2EA073),
        'needs_attention' => const Color(0xFFD97D24),
        'overdue' => const Color(0xFFDC4444),
        _ => const Color(0xFF94A3B8),
      };

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final d = decision;

    Widget card = Container(
      width: fixedWidth,
      height: fixedHeight,
      constraints:
          fixedHeight == null ? const BoxConstraints(minHeight: 72) : null,
      decoration: BoxDecoration(
        color: cs.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.borderDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Health indicator dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _healthColour(d.healthState),
            ),
          ),
          const SizedBox(width: 10),
          // Title + state badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  d.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                _StateBadge(state: d.state),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Confidence chip
          if (d.initialConfidence != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF19CBD6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${d.initialConfidence}/10',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF19CBD6),
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap != null) {
      card = GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

// ── State badge (pill with dot) ───────────────────────────────────────────────

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state});
  final String state;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final Color bg;
    final Color dot;
    final Color fg;

    switch (state.toLowerCase()) {
      case 'active':
        bg = const Color(0xFF19CBD6).withValues(alpha: 0.1);
        dot = const Color(0xFF19CBD6);
        fg = const Color(0xFF19CBD6);
      case 'draft':
        bg = cs.backgroundElevated;
        dot = const Color(0xFF94A3B8);
        fg = cs.textSecondary;
      case 'closed':
        bg = const Color(0xFF2EA073).withValues(alpha: 0.1);
        dot = const Color(0xFF2EA073);
        fg = const Color(0xFF2EA073);
      case 'archived':
        bg = cs.backgroundElevated;
        dot = const Color(0xFF7D8494);
        fg = cs.textTertiary;
      default:
        bg = cs.backgroundElevated;
        dot = const Color(0xFF94A3B8);
        fg = cs.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
          ),
          const SizedBox(width: 5),
          Text(
            state,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fan deck (collapsed group — physical card spread) ────────────────────────

class _FanDeck extends StatelessWidget {
  const _FanDeck({
    required this.decisions,
    required this.onTapFront,
    required this.onExpandStack,
  });

  final List<Decision> decisions;
  final ValueChanged<String> onTapFront;
  final VoidCallback onExpandStack;

  // Front card (index 0) is rightmost; back cards fan to the left.
  static const _rotations = [0.0, -0.06, -0.12, -0.18, -0.22];
  static const _translateX = [0.0, -14.0, -28.0, -42.0, -54.0];
  static const _translateY = [0.0, 6.0, 12.0, 18.0, 22.0];
  static const _opacities = [1.0, 0.88, 0.72, 0.56, 0.40];

  // Left buffer keeps back cards inside the SizedBox.
  static const double _leftBuffer = 60.0;
  static const double _cardW = 200.0;
  static const double _cardH = 76.0;
  static const double _stackW = _leftBuffer + _cardW + 40.0; // 300px
  static const double _stackH = _cardH + 22.0 + 20.0; // 118px

  @override
  Widget build(BuildContext context) {
    if (decisions.isEmpty) return const SizedBox.shrink();
    final visible = decisions.take(5).toList();
    final extra = decisions.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _stackW,
          height: _stackH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Draw back cards first (highest index = furthest behind)
              for (int i = visible.length - 1; i >= 0; i--)
                Positioned(
                  left: _leftBuffer + _translateX[i],
                  top: _translateY[i],
                  child: Transform.rotate(
                    angle: _rotations[i],
                    alignment: Alignment.bottomCenter,
                    child: Opacity(
                      opacity: _opacities[i],
                      child: i == 0
                          ? _CollapsedCard(
                              decision: visible[i],
                              fixedWidth: _cardW,
                              fixedHeight: _cardH,
                              onTap: () => onTapFront(visible[i].id),
                            )
                          : IgnorePointer(
                              child: _CollapsedCard(
                                decision: visible[i],
                                fixedWidth: _cardW,
                                fixedHeight: _cardH,
                              ),
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Pill expand button
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: onExpandStack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF19CBD6),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF19CBD6).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.expand_more,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${decisions.length} decision${decisions.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (extra > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              '+$extra more',
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ),
      ],
    );
  }
}

// ── Expanded card (full detail) ───────────────────────────────────────────────

class _ExpandedCard extends StatelessWidget {
  const _ExpandedCard({
    required this.decision,
    required this.detail,
    required this.onCollapse,
  });

  final Decision decision;

  /// `null` means the detail is still loading.
  final _DecisionCardDetail? detail;
  final VoidCallback onCollapse;

  static int _effectiveConfidence(Decision d, int coachAdjust) {
    final base = d.initialConfidence ?? 5;
    return (base + coachAdjust).clamp(1, 10);
  }

  static String _confidenceLabel(int score) {
    if (score >= 8) return 'highly confident';
    if (score >= 6) return 'moderately confident';
    if (score >= 4) return 'cautiously confident';
    return 'low confidence';
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  static String _checkpointTypeLabel(String type) => switch (type) {
        '30_day' => '30-day',
        '90_day' => '90-day',
        '180_day' => '180-day',
        '6_month' => '6-month',
        '12_month' => '12-month',
        '24_month' => '24-month',
        'monthly_continuous' => 'Monthly',
        'custom' => 'Custom',
        _ => type.replaceAll('_', ' '),
      };

  static String _checkpointStatusLabel(_ReviewCheckpointSummary cp) {
    if (cp.status == 'Completed') return 'On track';
    if (cp.status == 'Snoozed') return 'Snoozed';
    if (cp.status == 'Skipped') return 'Skipped';
    if (cp.status == 'Cancelled') return 'Cancelled';
    // Scheduled — check due date
    final diff = cp.dueAt.difference(DateTime.now()).inDays;
    if (diff < 0) return 'Overdue';
    if (diff < 7) return 'Due soon';
    return 'Pending review';
  }

  static Color _checkpointColour(String status) => switch (status) {
        'Completed' => const Color(0xFF2EA073),
        'Snoozed' => const Color(0xFFD97D24),
        'Skipped' || 'Cancelled' => const Color(0xFF7D8494),
        _ => const Color(0xFF19CBD6), // Scheduled
      };

  static const TextStyle _sectionHeader = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: Color(0xFF7D8494),
    letterSpacing: 0.8,
  );

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final d = decision;
    final loadedDetail = detail;
    final coachAdjust = loadedDetail?.coachAdjustmentSum ?? 0;
    final effectiveConf = _effectiveConfidence(d, coachAdjust);

    return Container(
      decoration: BoxDecoration(
        color: cs.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.borderDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: cs.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Made ${_formatDate(d.createdAt)}',
                      style: TextStyle(fontSize: 12, color: cs.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StateBadge(state: d.state),
            ],
          ),

          // ── Divider ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: cs.borderSubtle, height: 1),
          ),

          // ── Loading indicator ──────────────────────────────────────────────
          if (loadedDetail == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF19CBD6),
                  ),
                ),
              ),
            )
          else ...[
            // ── Confidence ─────────────────────────────────────────────────
            const Text('CONFIDENCE AT TIME OF DECISION',
                style: _sectionHeader),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: effectiveConf / 10,
                minHeight: 6,
                backgroundColor: cs.backgroundElevated,
                valueColor:
                    const AlwaysStoppedAnimation(Color(0xFF19CBD6)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${effectiveConf * 10}% — ${_confidenceLabel(effectiveConf)}',
              style: TextStyle(fontSize: 12, color: cs.textSecondary),
            ),

            // ── Tags ───────────────────────────────────────────────────────
            if (loadedDetail.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('RISK FACTORS IDENTIFIED', style: _sectionHeader),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in loadedDetail.tags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: cs.borderDefault),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                            fontSize: 12, color: cs.textSecondary),
                      ),
                    ),
                ],
              ),
            ],

            // ── Checkpoints ────────────────────────────────────────────────
            if (loadedDetail.checkpoints.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: cs.borderSubtle, height: 1),
              ),
              const Text('OUTCOME CHECKPOINTS', style: _sectionHeader),
              const SizedBox(height: 8),
              for (final cp in loadedDetail.checkpoints)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.backgroundElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _checkpointColour(cp.status),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${_checkpointTypeLabel(cp.checkpointType)} — ${_checkpointStatusLabel(cp)}',
                          style: TextStyle(
                              fontSize: 13, color: cs.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],

          // ── Action row ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        context.push('/decisions/detail/${d.id}'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF19CBD6)),
                      foregroundColor: const Color(0xFF19CBD6),
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('View decision'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.keyboard_arrow_up,
                      color: cs.textTertiary),
                  onPressed: onCollapse,
                  tooltip: 'Collapse',
                ),
              ],
            ),
          ),
        ],
      ),
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
