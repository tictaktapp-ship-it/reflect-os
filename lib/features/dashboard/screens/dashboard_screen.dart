import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/features/dashboard/providers/dashboard_provider.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decisionsAsync = ref.watch(decisionsProvider);
    final analyticsAsync = ref.watch(dashboardAnalyticsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: decisionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load: $e', textAlign: TextAlign.center),
          ),
        ),
        data: (decisions) {
          // Derive counts client-side from the already-fetched list.
          final total = decisions.length;
          final draft =
              decisions.where((d) => d.state == 'Draft').length;
          final active =
              decisions.where((d) => d.state == 'Active').length;
          final closed =
              decisions.where((d) => d.state == 'Closed').length;
          final archived =
              decisions.where((d) => d.state == 'Archived').length;

          // decisionsProvider is sorted by created_at desc — first 5 are most recent.
          final recent = decisions.take(5).toList();

          // Avg quality from analytics_summary (precomputed).
          final avgQuality =
              analyticsAsync.valueOrNull?.avgOutcomeQualityScore;
          final avgQualityStr = avgQuality != null
              ? '${avgQuality.toStringAsFixed(1)} / 10'
              : '—';

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Stats grid ─────────────────────────────────────
                  _StatsGrid(
                    isWide: isWide,
                    tiles: [
                      _StatTile(
                        label: 'Total Decisions',
                        value: '$total',
                      ),
                      _StatTile(
                        label: 'Active',
                        value: '$active',
                        valueColor: AppColors.accentHover,
                      ),
                      _StatTile(
                        label: 'Draft',
                        value: '$draft',
                        valueColor: AppColors.textSecondary,
                      ),
                      _StatTile(
                        label: 'Closed',
                        value: '$closed',
                        valueColor: AppColors.success,
                      ),
                      _StatTile(
                        label: 'Archived',
                        value: '$archived',
                        valueColor: AppColors.textMuted,
                      ),
                      _StatTile(
                        label: 'Avg Quality Score',
                        value: avgQualityStr,
                        valueColor: AppColors.accentHover,
                      ),
                    ],
                  ),

                  // ── Recent decisions ───────────────────────────────
                  if (recent.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                          top: 24, bottom: 8, left: 4),
                      child: Text(
                        'Recent Decisions',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                    ...recent.map(
                      (d) => _RecentDecisionTile(decision: d),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ── Stats grid ─────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.isWide, required this.tiles});

  final bool isWide;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    if (!isWide) {
      return Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            tiles[i],
            if (i < tiles.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }

    // 2-column grid built from paired rows.
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: tiles[i]),
            const SizedBox(width: 12),
            Expanded(
              child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox(),
            ),
          ],
        ),
      );
      if (i + 2 < tiles.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }
}

// ── Stat tile ──────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.backgroundSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent decision tile ───────────────────────────────────────────────────────

class _RecentDecisionTile extends StatelessWidget {
  const _RecentDecisionTile({required this.decision});

  final Decision decision;

  Color _backgroundFor(String state) => switch (state.toLowerCase()) {
        'active' => AppColors.accentPrimary.withValues(alpha: 0.2),
        'draft' => AppColors.textMuted.withValues(alpha: 0.2),
        'closed' => AppColors.success.withValues(alpha: 0.2),
        'archived' => AppColors.textMuted.withValues(alpha: 0.15),
        _ => AppColors.textMuted.withValues(alpha: 0.2),
      };

  Color _foregroundFor(String state) => switch (state.toLowerCase()) {
        'active' => AppColors.accentHover,
        'draft' => AppColors.textSecondary,
        'closed' => AppColors.success,
        'archived' => AppColors.textMuted,
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      margin: const EdgeInsets.only(bottom: 8),
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _backgroundFor(decision.state),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  decision.state,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _foregroundFor(decision.state),
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
