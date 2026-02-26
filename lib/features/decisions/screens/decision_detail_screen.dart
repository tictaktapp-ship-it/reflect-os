import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/decisions/data/models/review_checkpoint.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';
import 'package:reflect_os/features/initiatives/providers/initiatives_provider.dart';
import 'package:reflect_os/features/outcomes/data/models/outcome_update.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/features/tags/data/models/tag.dart';
import 'package:reflect_os/features/tags/providers/tags_provider.dart';
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
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => context.push(
              '/decisions/edit/${decision.id}',
              extra: decision,
            ),
          ),
        ],
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

          // ── Initiatives ───────────────────────────────────────
          _InitiativesSection(decisionId: decision.id),

          // ── Tags ──────────────────────────────────────────────
          _TagsSection(decisionId: decision.id),

          // ── Review Checkpoints ────────────────────────────────
          if (decision.state == 'Active' || decision.state == 'Closed')
            _CheckpointsSection(decisionId: decision.id),

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

// ── Initiatives section ────────────────────────────────────────────────────────

class _InitiativesSection extends ConsumerStatefulWidget {
  const _InitiativesSection({required this.decisionId});

  final String decisionId;

  @override
  ConsumerState<_InitiativesSection> createState() =>
      _InitiativesSectionState();
}

class _InitiativesSectionState extends ConsumerState<_InitiativesSection> {
  bool _isLoading = false;

  Future<void> _link(String initiativeId) async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(initiativesRepositoryProvider)
          .linkInitiativeToDecision(widget.decisionId, initiativeId);
      ref.invalidate(initiativesForDecisionProvider(widget.decisionId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to link: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unlink(String initiativeId) async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(initiativesRepositoryProvider)
          .unlinkInitiativeFromDecision(widget.decisionId, initiativeId);
      ref.invalidate(initiativesForDecisionProvider(widget.decisionId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to unlink: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddSheet() async {
    // Await all-initiatives load (triggers fetch if not yet cached).
    final all = await ref.read(initiativesProvider.future);
    if (!mounted) return;

    final linked = ref
            .read(initiativesForDecisionProvider(widget.decisionId))
            .valueOrNull ??
        [];
    final linkedIds = linked.map((i) => i.id).toSet();
    final available =
        all.where((i) => !linkedIds.contains(i.id)).toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('All initiatives are already linked.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                'Link an Initiative',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...available.map(
              (initiative) => ListTile(
                title: Text(initiative.name),
                onTap: () {
                  Navigator.of(context).pop();
                  _link(initiative.id);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initiativesAsync =
        ref.watch(initiativesForDecisionProvider(widget.decisionId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Initiatives',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
              SizedBox(
                width: 32,
                height: 32,
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        padding: EdgeInsets.zero,
                        tooltip: 'Link initiative',
                        onPressed: _showAddSheet,
                      ),
              ),
            ],
          ),
        ),

        // Content
        _SectionCard(
          children: [
            initiativesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(
                'Failed to load initiatives.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textMuted),
              ),
              data: (initiatives) {
                if (initiatives.isEmpty) {
                  return Text(
                    'No initiatives linked.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textMuted),
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: initiatives
                      .map(
                        (i) => Chip(
                          label: Text(i.name),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted:
                              _isLoading ? null : () => _unlink(i.id),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ── Tags section ───────────────────────────────────────────────────────────────

class _TagsSection extends ConsumerStatefulWidget {
  const _TagsSection({required this.decisionId});

  final String decisionId;

  @override
  ConsumerState<_TagsSection> createState() => _TagsSectionState();
}

class _TagsSectionState extends ConsumerState<_TagsSection> {
  bool _isLoading = false;

  Future<void> _add(String tagId) async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(tagsRepositoryProvider)
          .addTagToDecision(widget.decisionId, tagId);
      ref.invalidate(decisionTagsProvider(widget.decisionId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to add tag: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _remove(String tagId) async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(tagsRepositoryProvider)
          .removeTagFromDecision(widget.decisionId, tagId);
      ref.invalidate(decisionTagsProvider(widget.decisionId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to remove tag: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddSheet(List<Tag> linked) {
    final workspaceTags = ref.read(workspaceTagsProvider).valueOrNull ?? [];
    final linkedIds = linked.map((t) => t.id).toSet();
    final available =
        workspaceTags.where((t) => !linkedIds.contains(t.id)).toList();

    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> createAndLink(String name) async {
              final trimmed = name.trim();
              if (trimmed.isEmpty) return;
              Navigator.of(sheetContext).pop();
              setState(() => _isLoading = true);
              try {
                final workspaceId =
                    await ref.read(currentWorkspaceProvider.future);
                if (workspaceId == null) return;
                final tag = await ref
                    .read(tagsRepositoryProvider)
                    .createTag(workspaceId, trimmed);
                await ref
                    .read(tagsRepositoryProvider)
                    .addTagToDecision(widget.decisionId, tag.id);
                ref.invalidate(workspaceTagsProvider);
                ref.invalidate(decisionTagsProvider(widget.decisionId));
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create tag: $e')));
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Add Tag',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Create new tag…',
                        suffixIcon: Icon(Icons.add),
                      ),
                      onSubmitted: createAndLink,
                    ),
                  ),
                  if (available.isNotEmpty) ...[
                    const Divider(height: 24),
                    ...available.map(
                      (tag) => ListTile(
                        title: Text(tag.name),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _add(tag.id);
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(decisionTagsProvider(widget.decisionId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Tags',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
              SizedBox(
                width: 32,
                height: 32,
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        padding: EdgeInsets.zero,
                        tooltip: 'Add tag',
                        onPressed: tagsAsync.valueOrNull != null
                            ? () => _showAddSheet(tagsAsync.valueOrNull!)
                            : null,
                      ),
              ),
            ],
          ),
        ),

        // Content
        _SectionCard(
          children: [
            tagsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(
                'Failed to load tags.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textMuted),
              ),
              data: (tags) {
                if (tags.isEmpty) {
                  return Text(
                    'No tags.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textMuted),
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: tags
                      .map(
                        (t) => Chip(
                          label: Text(t.name),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: _isLoading ? null : () => _remove(t.id),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ── Checkpoints section ────────────────────────────────────────────────────────

class _CheckpointsSection extends ConsumerWidget {
  const _CheckpointsSection({required this.decisionId});

  final String decisionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkpointsAsync = ref.watch(checkpointsProvider(decisionId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
          child: Text(
            'Review Checkpoints',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
        _SectionCard(
          children: [
            checkpointsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(
                'Failed to load checkpoints.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textMuted),
              ),
              data: (checkpoints) {
                if (checkpoints.isEmpty) {
                  return Text(
                    'No checkpoints scheduled.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textMuted),
                  );
                }
                return Column(
                  children: [
                    for (int i = 0; i < checkpoints.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _CheckpointRow(checkpoint: checkpoints[i]),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _CheckpointRow extends StatelessWidget {
  const _CheckpointRow({required this.checkpoint});

  final ReviewCheckpoint checkpoint;

  static String _formatType(String type) {
    switch (type) {
      case '30_day':
        return '30 Day';
      case '90_day':
        return '90 Day';
      case '180_day':
        return '180 Day';
      case '6_month':
        return '6 Month';
      case '12_month':
        return '12 Month';
      case '24_month':
        return '24 Month';
      case 'monthly_continuous':
        return 'Monthly';
      case 'custom':
        return 'Custom';
      default:
        return type.replaceAll('_', ' ');
    }
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'Scheduled':
        return AppColors.warning;
      case 'Completed':
        return AppColors.success;
      case 'Snoozed':
        return AppColors.accentPrimary;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayDate =
        checkpoint.status == 'Snoozed' && checkpoint.snoozedUntil != null
            ? checkpoint.snoozedUntil!
            : checkpoint.dueAt;
    final color = _statusColor(checkpoint.status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatType(checkpoint.checkpointType),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  DateFormat('d MMM yyyy').format(displayDate),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              checkpoint.status,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
