import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';
import 'package:reflect_os/features/outcomes/data/models/outcome_update.dart';
import 'package:reflect_os/features/outcomes/providers/outcomes_provider.dart';

class DecisionDetailScreen extends ConsumerWidget {
  const DecisionDetailScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decisionAsync = ref.watch(decisionDetailProvider(id));

    return decisionAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load decision: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (decision) {
        if (decision == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Decision not found.')),
          );
        }
        return _DecisionDetail(decision: decision);
      },
    );
  }
}

class _DecisionDetail extends ConsumerWidget {
  const _DecisionDetail({required this.decision});

  final Decision decision;

  String _formatDate(DateTime dt) =>
      DateFormat('d MMM yyyy').format(dt.toLocal());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcomesAsync = ref.watch(outcomesProvider(decision.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          decision.title,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            context.push('/outcomes/create/${decision.id}'),
        tooltip: 'Add outcome',
        child: const Icon(Icons.add_chart_outlined),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── State transitions ─────────────────────────────────────
          _StateTransitionBar(decision: decision),

          // ── State & health ────────────────────────────────────────
          _SectionCard(
            children: [
              Row(
                children: [
                  _StateBadge(state: decision.state),
                  if (decision.healthState != null) ...[
                    const SizedBox(width: 8),
                    _HealthBadge(healthState: decision.healthState!),
                  ],
                ],
              ),
            ],
          ),

          // ── Overview ──────────────────────────────────────────────
          _SectionCard(
            children: [
              if (decision.stakes != null)
                _DetailRow(label: 'Stakes', value: decision.stakes!),
              if (decision.categoryName != null)
                _DetailRow(label: 'Category', value: decision.categoryName!),
              if (decision.initialConfidence != null)
                _DetailRow(
                  label: 'Initial confidence',
                  value: '${decision.initialConfidence} / 10',
                ),
            ],
          ),

          // ── Description ───────────────────────────────────────────
          if (decision.descriptionEncrypted != null)
            _SectionCard(
              children: [
                _DetailRow(
                  label: 'Description',
                  value: decision.descriptionEncrypted!,
                  valueMaxLines: null,
                ),
              ],
            ),

          // ── Dates ─────────────────────────────────────────────────
          _SectionCard(
            children: [
              if (decision.decisionDeadline != null)
                _DetailRow(
                  label: 'Deadline',
                  value: _formatDate(decision.decisionDeadline!),
                ),
              _DetailRow(
                label: 'Created',
                value: _formatDate(decision.createdAt),
              ),
              _DetailRow(
                label: 'Updated',
                value: _formatDate(decision.updatedAt),
              ),
            ],
          ),

          // ── Outcomes ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 8, bottom: 8),
            child: Text(
              'Outcomes',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          ...outcomesAsync.when(
            loading: () => [
              _SectionCard(
                children: const [
                  Center(child: CircularProgressIndicator()),
                ],
              ),
            ],
            error: (e, _) => [
              _SectionCard(
                children: [
                  Text(
                    'Failed to load outcomes.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                ],
              ),
            ],
            data: (outcomes) {
              if (outcomes.isEmpty) {
                return [
                  _SectionCard(
                    children: [
                      Text(
                        'No outcomes recorded yet.',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textMuted,
                                ),
                      ),
                    ],
                  ),
                ];
              }
              return outcomes
                  .map((o) => _OutcomeCard(
                        outcome: o,
                        formatDate: _formatDate,
                      ))
                  .toList();
            },
          ),

          const SizedBox(height: 80), // clear the FAB
        ],
      ),
    );
  }
}

// ── Outcome card ───────────────────────────────────────────────────────────────

class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({required this.outcome, required this.formatDate});

  final OutcomeUpdate outcome;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      children: [
        Row(
          children: [
            Text(
              '${outcome.outcomeQualityScore} / 10',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(),
            if (outcome.outcomeState != null)
              _OutcomeStateBadge(state: outcome.outcomeState!),
          ],
        ),
        if (outcome.outcomeTextEncrypted != null) ...[
          const SizedBox(height: 8),
          _DetailRow(
            label: 'Outcome',
            value: outcome.outcomeTextEncrypted!,
            valueMaxLines: null,
          ),
        ],
        if (outcome.lessonsLearnedEncrypted != null)
          _DetailRow(
            label: 'Lessons Learned',
            value: outcome.lessonsLearnedEncrypted!,
            valueMaxLines: null,
          ),
        _DetailRow(
          label: 'Recorded',
          value: formatDate(outcome.createdAt),
        ),
      ],
    );
  }
}

// ── Outcome state badge ────────────────────────────────────────────────────────

class _OutcomeStateBadge extends StatelessWidget {
  const _OutcomeStateBadge({required this.state});

  final String state;

  Color get _background => switch (state) {
        'Unrealised' => AppColors.textMuted.withValues(alpha: 0.2),
        'Partial' => AppColors.warning.withValues(alpha: 0.2),
        'Realised' => AppColors.success.withValues(alpha: 0.2),
        'Written_off' => AppColors.destructive.withValues(alpha: 0.2),
        _ => AppColors.textMuted.withValues(alpha: 0.2),
      };

  Color get _foreground => switch (state) {
        'Unrealised' => AppColors.textMuted,
        'Partial' => AppColors.warning,
        'Realised' => AppColors.success,
        'Written_off' => AppColors.destructive,
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        state.replaceAll('_', ' '),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ── Shared section card ────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final nonEmpty = children.where((w) {
      if (w is _DetailRow) return true;
      return true;
    }).toList();

    if (nonEmpty.isEmpty) return const SizedBox.shrink();

    return Card(
      color: AppColors.backgroundSurface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: nonEmpty,
        ),
      ),
    );
  }
}

// ── Detail row ────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueMaxLines = 1,
  });

  final String label;
  final String value;
  final int? valueMaxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: valueMaxLines,
            overflow:
                valueMaxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
          ),
        ],
      ),
    );
  }
}

// ── State transition bar ──────────────────────────────────────────────────────

class _StateTransitionBar extends ConsumerStatefulWidget {
  const _StateTransitionBar({required this.decision});

  final Decision decision;

  @override
  ConsumerState<_StateTransitionBar> createState() =>
      _StateTransitionBarState();
}

class _StateTransitionBarState extends ConsumerState<_StateTransitionBar> {
  bool _isLoading = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isLoading = true);
    try {
      await action();
      ref.invalidate(decisionDetailProvider(widget.decision.id));
      ref.invalidate(decisionsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showUnarchiveSheet() async {
    final newState = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                'Restore to which state?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('Active'),
              onTap: () => Navigator.of(context).pop('Active'),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Closed'),
              onTap: () => Navigator.of(context).pop('Closed'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (newState != null) {
      await _run(() => ref
          .read(decisionsRepositoryProvider)
          .unarchiveDecision(widget.decision.id, newState));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(decisionsRepositoryProvider);
    final id = widget.decision.id;
    final state = widget.decision.state;

    final buttons = switch (state) {
      'Draft' => <Widget>[
          OutlinedButton(
            onPressed:
                _isLoading ? null : () => _run(() => repo.activateDecision(id)),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentHover),
            child: const Text('Activate'),
          ),
        ],
      'Active' => <Widget>[
          OutlinedButton(
            onPressed:
                _isLoading ? null : () => _run(() => repo.closeDecision(id)),
            style:
                OutlinedButton.styleFrom(foregroundColor: AppColors.success),
            child: const Text('Close'),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed:
                _isLoading ? null : () => _run(() => repo.archiveDecision(id)),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            child: const Text('Archive'),
          ),
        ],
      'Closed' => <Widget>[
          OutlinedButton(
            onPressed:
                _isLoading ? null : () => _run(() => repo.reopenDecision(id)),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentHover),
            child: const Text('Reopen'),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed:
                _isLoading ? null : () => _run(() => repo.archiveDecision(id)),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            child: const Text('Archive'),
          ),
        ],
      'Archived' => <Widget>[
          OutlinedButton(
            onPressed: _isLoading ? null : _showUnarchiveSheet,
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentHover),
            child: const Text('Unarchive'),
          ),
        ],
      _ => <Widget>[],
    };

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Card(
      color: AppColors.backgroundSurface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (_isLoading) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
            ],
            ...buttons,
          ],
        ),
      ),
    );
  }
}

// ── State badge ───────────────────────────────────────────────────────────────

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state});

  final String state;

  Color get _background => switch (state.toLowerCase()) {
        'active' => AppColors.accentPrimary.withValues(alpha: 0.2),
        'draft' => AppColors.textMuted.withValues(alpha: 0.2),
        'closed' => AppColors.success.withValues(alpha: 0.2),
        'archived' => AppColors.textMuted.withValues(alpha: 0.15),
        _ => AppColors.textMuted.withValues(alpha: 0.2),
      };

  Color get _foreground => switch (state.toLowerCase()) {
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
        color: _background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        state,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ── Health badge ──────────────────────────────────────────────────────────────

class _HealthBadge extends StatelessWidget {
  const _HealthBadge({required this.healthState});

  final String healthState;

  Color get _background => switch (healthState.toLowerCase()) {
        'healthy' => AppColors.success.withValues(alpha: 0.2),
        'at_risk' => AppColors.warning.withValues(alpha: 0.2),
        'off_track' => AppColors.destructive.withValues(alpha: 0.2),
        _ => AppColors.textMuted.withValues(alpha: 0.2),
      };

  Color get _foreground => switch (healthState.toLowerCase()) {
        'healthy' => AppColors.success,
        'at_risk' => AppColors.warning,
        'off_track' => AppColors.destructive,
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        healthState.replaceAll('_', ' '),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
