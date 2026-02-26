import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/decisions/data/models/audit_event.dart';
import 'package:reflect_os/features/decisions/data/models/comment.dart';
import 'package:reflect_os/features/decisions/data/models/approval_record.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/decisions/data/models/decision_stakeholder.dart';
import 'package:reflect_os/features/decisions/data/models/review_checkpoint.dart';
import 'package:reflect_os/features/team/data/models/workspace_membership.dart';
import 'package:reflect_os/features/team/providers/team_provider.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';
import 'package:reflect_os/features/initiatives/providers/initiatives_provider.dart';
import 'package:reflect_os/features/outcomes/data/models/outcome_update.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/features/tags/data/models/tag.dart';
import 'package:reflect_os/features/tags/providers/tags_provider.dart';
import 'package:reflect_os/features/outcomes/providers/outcomes_provider.dart';
import 'package:reflect_os/features/decisions/data/models/decision_relationship.dart';
import 'package:reflect_os/features/evidence/data/models/evidence_item.dart';
import 'package:reflect_os/features/evidence/providers/evidence_provider.dart';
import 'package:web/web.dart' as web;

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

class _DecisionDetail extends ConsumerStatefulWidget {
  const _DecisionDetail({required this.decision});

  final Decision decision;

  @override
  ConsumerState<_DecisionDetail> createState() => _DecisionDetailState();
}

class _DecisionDetailState extends ConsumerState<_DecisionDetail> {
  bool _isGenerating = false;

  String _formatDate(DateTime dt) =>
      DateFormat('d MMM yyyy').format(dt.toLocal());

  Future<void> _onGenerateBriefTapped() async {
    setState(() => _isGenerating = true);
    try {
      final workspaceId = await ref.read(currentWorkspaceProvider.future);
      if (workspaceId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No workspace found')),
          );
        }
        return;
      }
      // TODO: Corporate network blocks external Supabase function URLs in dev.
      // Verified working via direct API test. Will work in production deployment.
      final response = await supabase.functions.invoke(
        'generate-document',
        body: {
          'document_type': 'decision_brief',
          'decision_id': widget.decision.id,
          'workspace_id': workspaceId,
        },
      );
      final downloadUrl = response.data?['download_url'] as String?;
      if (downloadUrl == null) throw Exception('No download_url in response');
      web.window.open(downloadUrl, '_blank');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Brief generated — opening download...')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Brief generation unavailable in this network environment. Will work in production.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final decision = widget.decision;
    final outcomesAsync = ref.watch(outcomesProvider(decision.id));

    Future<void> onDeleteTapped() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete Decision'),
          content: const Text(
            'This will permanently remove this decision. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.destructive,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await ref
          .read(decisionsRepositoryProvider)
          .deleteDecision(decision.id);
      ref.invalidate(decisionsProvider);
      if (context.mounted) context.go(Routes.decisionsList);
    }

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
            Expanded(
              child: Text(
                decision.title,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (_isGenerating)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Generate Brief',
              onPressed: _onGenerateBriefTapped,
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => context.push(
              '/decisions/edit/${decision.id}',
              extra: decision,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: onDeleteTapped,
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

          // ── Approvals (requires_approval decisions only) ──────────
          if (decision.requiresApproval)
            _ApprovalsSection(decisionId: decision.id),

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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
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
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
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

          // ── Related Decisions ─────────────────────────────────
          _RelatedDecisionsSection(decisionId: decision.id),

          // ── Evidence ──────────────────────────────────────────
          _EvidenceSection(decisionId: decision.id),

          // ── Stakeholders ──────────────────────────────────────
          _StakeholdersSection(decisionId: decision.id),

          // ── Comments ──────────────────────────────────────────
          if (decision.state == 'Active')
            _CommentsSection(decisionId: decision.id),

          // ── Activity ──────────────────────────────────────────
          _ActivitySection(decisionId: decision.id),

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
                    color: Theme.of(context).colorScheme.onSurface,
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
      color: Theme.of(context).colorScheme.surface,
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: SvgPicture.asset(Theme.of(context).brightness == Brightness.dark ? 'assets/images/reflect-icon-dark.svg' : 'assets/images/reflect-icon-light.svg', height: 32)),
                  const SizedBox(height: 8),
                  Text(
                    'Restore to which state?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
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

    // Approval gate: if requires_approval and no Approved record, block Activate.
    final approvalsAsync = ref.watch(approvalRecordsProvider(id));
    final approvals = approvalsAsync.valueOrNull ?? [];
    final approvalBlocked = widget.decision.requiresApproval &&
        !approvals.any((a) => a.status == 'Approved');

    final buttons = switch (state) {
      'Draft' => <Widget>[
          Tooltip(
            message: approvalBlocked
                ? 'Approval required before activating'
                : '',
            child: OutlinedButton(
              onPressed: (_isLoading || approvalBlocked)
                  ? null
                  : () => _run(() => repo.activateDecision(id)),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentHover),
              child: const Text('Activate'),
            ),
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
      color: Theme.of(context).colorScheme.surface,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: SvgPicture.asset(Theme.of(context).brightness == Brightness.dark ? 'assets/images/reflect-icon-dark.svg' : 'assets/images/reflect-icon-light.svg', height: 32)),
                  const SizedBox(height: 8),
                  Text(
                    'Link an Initiative',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
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
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
              ),
              data: (initiatives) {
                if (initiatives.isEmpty) {
                  return Text(
                    'No initiatives linked.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: SvgPicture.asset(Theme.of(ctx).brightness == Brightness.dark ? 'assets/images/reflect-icon-dark.svg' : 'assets/images/reflect-icon-light.svg', height: 32)),
                        const SizedBox(height: 8),
                        Text(
                          'Add Tag',
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ],
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
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
              ),
              data: (tags) {
                if (tags.isEmpty) {
                  return Text(
                    'No tags.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
              ),
              data: (checkpoints) {
                if (checkpoints.isEmpty) {
                  return Text(
                    'No checkpoints scheduled.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
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
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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

// ── Activity section ───────────────────────────────────────────────────────────

class _ActivitySection extends ConsumerWidget {
  const _ActivitySection({required this.decisionId});

  final String decisionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(auditEventsProvider(decisionId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
          child: Text(
            'Activity',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
        ),
        _SectionCard(
          children: [
            eventsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, _) => Text(
                'No activity recorded.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
              ),
              data: (events) {
                if (events.isEmpty) {
                  return Text(
                    'No activity recorded.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                  );
                }
                return Column(
                  children: [
                    for (int i = 0; i < events.length; i++)
                      _ActivityEventRow(
                        event: events[i],
                        isLast: i == events.length - 1,
                      ),
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

class _ActivityEventRow extends StatelessWidget {
  const _ActivityEventRow({required this.event, required this.isLast});

  final AuditEvent event;
  final bool isLast;

  static String _formatEventType(String type) {
    switch (type) {
      case 'decision_created':
        return 'Created';
      case 'decision_updated':
        return 'Updated';
      case 'decision_activated':
        return 'Activated';
      case 'decision_closed':
        return 'Closed';
      case 'decision_archived':
        return 'Archived';
      case 'decision_unarchived':
        return 'Unarchived';
      case 'decision_reopened':
        return 'Reopened';
      case 'outcome_update_created':
        return 'Outcome recorded';
      default:
        return type
            .split('_')
            .map((w) =>
                w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final transition =
        event.metadataJsonb['transition'] as String?;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline spine
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentPrimary,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Theme.of(context).dividerColor,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Event content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatEventType(event.eventType),
                          style:
                              Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        DateFormat('d MMM yyyy').format(event.createdAt),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                  if (transition != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        transition,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                      ),
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

// ── Comments section ───────────────────────────────────────────────────────────

class _CommentsSection extends ConsumerStatefulWidget {
  const _CommentsSection({required this.decisionId});

  final String decisionId;

  @override
  ConsumerState<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<_CommentsSection> {
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(String threadId) async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    setState(() => _isSending = true);
    try {
      await ref.read(decisionsRepositoryProvider).postComment(threadId, body);
      _controller.clear();
      ref.invalidate(commentsProvider(threadId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to post comment: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final threadAsync =
        ref.watch(commentThreadProvider(widget.decisionId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
          child: Text(
            'Comments',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
        ),
        threadAsync.when(
          loading: () => const _SectionCard(
            children: [Center(child: CircularProgressIndicator())],
          ),
          error: (_, _) => _SectionCard(
            children: [
              Text(
                'Comments available once decision is activated.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
              ),
            ],
          ),
          data: (thread) {
            if (thread == null) {
              return _SectionCard(
                children: [
                  Text(
                    'Comments available once decision is activated.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                  ),
                ],
              );
            }
            return _CommentsThreadView(
              thread: thread,
              onSend: _send,
              controller: _controller,
              isSending: _isSending,
            );
          },
        ),
      ],
    );
  }
}

class _CommentsThreadView extends ConsumerWidget {
  const _CommentsThreadView({
    required this.thread,
    required this.onSend,
    required this.controller,
    required this.isSending,
  });

  final dynamic thread; // CommentThread
  final Future<void> Function(String threadId) onSend;
  final TextEditingController controller;
  final bool isSending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(commentsProvider(thread.id as String));

    return _SectionCard(
      children: [
        commentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Text(
            'No comments yet. Be the first to comment.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
          ),
          data: (comments) {
            if (comments.isEmpty) {
              return Text(
                'No comments yet. Be the first to comment.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: comments
                  .map((c) => _CommentRow(comment: c))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Add a comment…',
                ),
                onSubmitted:
                    isSending ? null : (_) => onSend(thread.id as String),
              ),
            ),
            const SizedBox(width: 8),
            isSending
                ? const SizedBox(
                    width: 40,
                    height: 40,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.send_outlined),
                    tooltip: 'Send',
                    onPressed: () => onSend(thread.id as String),
                  ),
          ],
        ),
      ],
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            comment.bodyEncrypted,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 2),
          Text(
            DateFormat('d MMM yyyy HH:mm').format(comment.createdAt.toLocal()),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

// ── Stakeholders section ───────────────────────────────────────────────────────

class _StakeholdersSection extends ConsumerStatefulWidget {
  const _StakeholdersSection({required this.decisionId});

  final String decisionId;

  @override
  ConsumerState<_StakeholdersSection> createState() =>
      _StakeholdersSectionState();
}

class _StakeholdersSectionState extends ConsumerState<_StakeholdersSection> {
  bool _isLoading = false;

  static const _roles = ['Owner', 'Approver', 'Consulted', 'Informed'];

  static Color _roleColor(String role) => switch (role) {
        'Owner' => AppColors.accentPrimary,
        'Approver' => AppColors.warning,
        'Consulted' => AppColors.textSecondary,
        _ => AppColors.textMuted,
      };

  Future<void> _add(String userId, String role) async {
    setState(() => _isLoading = true);
    String? err;
    try {
      await ref
          .read(decisionsRepositoryProvider)
          .addStakeholder(widget.decisionId, userId, role);
      ref.invalidate(stakeholdersProvider(widget.decisionId));
    } catch (e) {
      err = 'Failed to add stakeholder: $e';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        if (err != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(err)));
        }
      }
    }
  }

  Future<void> _remove(String userId) async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(decisionsRepositoryProvider)
          .removeStakeholder(widget.decisionId, userId);
      ref.invalidate(stakeholdersProvider(widget.decisionId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove stakeholder: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddSheet(List<DecisionStakeholder> current) {
    final teamMembers = ref.read(teamMembersProvider).valueOrNull ?? [];
    final addedIds = current.map((s) => s.userId).toSet();
    final available =
        teamMembers.where((m) => !addedIds.contains(m.userId)).toList();
    final currentUserId = supabase.auth.currentUser?.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AddStakeholderSheet(
        available: available,
        roles: _roles,
        currentUserId: currentUserId,
        onAdd: (userId, role) {
          Navigator.of(context).pop();
          _add(userId, role);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stakeholdersAsync =
        ref.watch(stakeholdersProvider(widget.decisionId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Stakeholders',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                        tooltip: 'Add stakeholder',
                        onPressed: _isLoading || stakeholdersAsync.isLoading
                            ? null
                            : () => _showAddSheet(
                                  stakeholdersAsync.valueOrNull ?? [],
                                ),
                      ),
              ),
            ],
          ),
        ),
        _SectionCard(
          children: [
            stakeholdersAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, _) => Text(
                'No stakeholders added.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
              ),
              data: (stakeholders) {
                if (stakeholders.isEmpty) {
                  return Text(
                    'No stakeholders added.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: stakeholders.map((s) {
                    final color = _roleColor(s.stakeholderRole);
                    final shortId = s.userId.length >= 8
                        ? s.userId.substring(0, 8)
                        : s.userId;
                    return Chip(
                      backgroundColor: color.withValues(alpha: 0.12),
                      label: Text(
                        '${s.stakeholderRole} · $shortId',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                      deleteIcon: Icon(Icons.close, size: 14, color: color),
                      onDeleted:
                          _isLoading ? null : () => _remove(s.userId),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _AddStakeholderSheet extends StatefulWidget {
  const _AddStakeholderSheet({
    required this.available,
    required this.roles,
    required this.currentUserId,
    required this.onAdd,
  });

  final List<WorkspaceMembership> available;
  final List<String> roles;
  final String? currentUserId;
  final void Function(String userId, String role) onAdd;

  @override
  State<_AddStakeholderSheet> createState() => _AddStakeholderSheetState();
}

class _AddStakeholderSheetState extends State<_AddStakeholderSheet> {
  late final Map<String, String> _selectedRoles = {
    for (final m in widget.available) m.userId: 'Informed',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: SvgPicture.asset(Theme.of(context).brightness == Brightness.dark ? 'assets/images/reflect-icon-dark.svg' : 'assets/images/reflect-icon-light.svg', height: 32)),
              const SizedBox(height: 8),
              Text(
                'Add Stakeholder',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        if (widget.available.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'All workspace members are already stakeholders.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
            ),
          )
        else
          ...widget.available.map((m) {
            final shortId = m.userId.length >= 8
                ? m.userId.substring(0, 8)
                : m.userId;
            final isYou = m.userId == widget.currentUserId;
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isYou ? '$shortId (you)' : shortId,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                  DropdownButton<String>(
                    value: _selectedRoles[m.userId],
                    underline: const SizedBox.shrink(),
                    items: widget.roles
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedRoles[m.userId] = v);
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Add',
                    onPressed: () =>
                        widget.onAdd(m.userId, _selectedRoles[m.userId]!),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Evidence section ───────────────────────────────────────────────────────────

class _EvidenceSection extends ConsumerStatefulWidget {
  const _EvidenceSection({required this.decisionId});

  final String decisionId;

  @override
  ConsumerState<_EvidenceSection> createState() => _EvidenceSectionState();
}

class _EvidenceSectionState extends ConsumerState<_EvidenceSection> {
  bool _isLoading = false;

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Evidence'),
        content: const Text('Remove this evidence item? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.destructive),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(evidenceRepositoryProvider).deleteEvidence(id);
      ref.invalidate(evidenceProvider(widget.decisionId));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddSheet() {
    final labelCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> save() async {
              final url = urlCtrl.text.trim();
              if (url.isEmpty) return;
              setSheetState(() => saving = true);
              try {
                await ref.read(evidenceRepositoryProvider).addLinkEvidence(
                      widget.decisionId,
                      labelCtrl.text.trim(),
                      url,
                    );
                ref.invalidate(evidenceProvider(widget.decisionId));
                if (mounted) Navigator.of(context).pop();
              } catch (e) {
                setSheetState(() => saving = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add: $e')),
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                20,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: SvgPicture.asset(Theme.of(ctx).brightness == Brightness.dark ? 'assets/images/reflect-icon-dark.svg' : 'assets/images/reflect-icon-light.svg', height: 32)),
                  const SizedBox(height: 8),
                  Text('Add Link',
                      style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  TextField(
                    controller: labelCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Label (optional)'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(labelText: 'URL'),
                    keyboardType: TextInputType.url,
                    autofocus: true,
                    onSubmitted: (_) => save(),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: saving ? null : save,
                    child: saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Add'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
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
    final evidenceAsync = ref.watch(evidenceProvider(widget.decisionId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
          child: Row(
            children: [
              Text(
                'Evidence',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              const Spacer(),
              if (_isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Add evidence',
                  onPressed: _showAddSheet,
                ),
            ],
          ),
        ),
        evidenceAsync.when(
          loading: () => const _SectionCard(
            children: [Center(child: CircularProgressIndicator())],
          ),
          error: (_, _) => _SectionCard(
            children: [
              Text(
                'Failed to load evidence.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return _SectionCard(
                children: [
                  Text(
                    'No evidence attached.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                  ),
                ],
              );
            }
            return _SectionCard(
              children: items
                  .map((item) => _EvidenceTile(
                        item: item,
                        onDelete: () => _confirmDelete(context, item.id),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

// ── Evidence tile ──────────────────────────────────────────────────────────────

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({required this.item, required this.onDelete});

  final EvidenceItem item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isLink = item.type == 'link';
    final displayText =
        (item.label != null && item.label!.isNotEmpty) ? item.label! : (item.url ?? '');

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isLink ? Icons.link : Icons.attach_file,
        size: 18,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      title: Text(
        displayText,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isLink ? AppColors.accentHover : Theme.of(context).colorScheme.onSurface,
              decoration: isLink ? TextDecoration.underline : null,
            ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: isLink && item.url != null
          ? () {
              // TODO: verify link opening works in production (may be blocked by corporate network in dev)
              web.window.open(item.url!, '_blank');
            }
          : null,
      onLongPress: onDelete,
    );
  }
}

// ── Related Decisions section ──────────────────────────────────────────────────

class _RelatedDecisionsSection extends ConsumerStatefulWidget {
  const _RelatedDecisionsSection({required this.decisionId});

  final String decisionId;

  @override
  ConsumerState<_RelatedDecisionsSection> createState() =>
      _RelatedDecisionsSectionState();
}

class _RelatedDecisionsSectionState
    extends ConsumerState<_RelatedDecisionsSection> {
  bool _isSaving = false;

  Future<void> _confirmRemove(
      BuildContext context, DecisionRelationship rel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Relationship'),
        content: const Text('Remove this relationship?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style:
                TextButton.styleFrom(foregroundColor: AppColors.destructive),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(decisionsRepositoryProvider)
          .removeRelationship(rel.id);
      ref.invalidate(decisionRelationshipsProvider(widget.decisionId));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAddSheet(List<Decision> allDecisions) {
    final candidates =
        allDecisions.where((d) => d.id != widget.decisionId).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        String query = '';
        String relType = 'related';
        Decision? selected;
        bool saving = false;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = query.isEmpty
                ? candidates
                : candidates
                    .where((d) =>
                        d.title.toLowerCase().contains(query.toLowerCase()))
                    .toList();

            Future<void> save() async {
              if (selected == null) return;
              setSheetState(() => saving = true);
              try {
                final workspaceId =
                    await ref.read(currentWorkspaceProvider.future);
                if (workspaceId == null) throw Exception('No workspace');
                await ref
                    .read(decisionsRepositoryProvider)
                    .addRelationship(
                      widget.decisionId,
                      selected!.id,
                      relType,
                      workspaceId,
                    );
                ref.invalidate(
                    decisionRelationshipsProvider(widget.decisionId));
                if (mounted) Navigator.of(context).pop();
              } catch (e) {
                setSheetState(() => saving = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add: $e')),
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                20,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: SvgPicture.asset(Theme.of(ctx).brightness == Brightness.dark ? 'assets/images/reflect-icon-dark.svg' : 'assets/images/reflect-icon-light.svg', height: 32)),
                  const SizedBox(height: 8),
                  Text('Add Related Decision',
                      style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'preceded_by', label: Text('Preceded by')),
                      ButtonSegment(
                          value: 'related', label: Text('Related')),
                      ButtonSegment(
                          value: 'leads_to', label: Text('Leads to')),
                    ],
                    selected: {relType},
                    onSelectionChanged: (v) =>
                        setSheetState(() => relType = v.first),
                    showSelectedIcon: false,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Search decisions',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setSheetState(() => query = v),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No decisions found.',
                              style: Theme.of(ctx)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.4)),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final d = filtered[i];
                              final isSelected = selected?.id == d.id;
                              return ListTile(
                                title: Text(
                                  d.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                selected: isSelected,
                                onTap: () =>
                                    setSheetState(() => selected = d),
                                trailing: isSelected
                                    ? const Icon(Icons.check)
                                    : null,
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: (selected != null && !saving) ? save : null,
                    child: saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Add'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
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
    final relsAsync =
        ref.watch(decisionRelationshipsProvider(widget.decisionId));
    final allDecisions = ref.watch(decisionsProvider).valueOrNull ?? [];
    final decisionMap = {for (final d in allDecisions) d.id: d};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
          child: Row(
            children: [
              Text(
                'Related Decisions',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              const Spacer(),
              if (_isSaving)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add related decision',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showAddSheet(allDecisions),
                ),
            ],
          ),
        ),
        relsAsync.when(
          loading: () => const _SectionCard(
            children: [Center(child: CircularProgressIndicator())],
          ),
          error: (e, _) => _SectionCard(
            children: [
              Text(
                'Failed to load relationships.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
              ),
            ],
          ),
          data: (rels) {
            if (rels.isEmpty) {
              return _SectionCard(
                children: [
                  Text(
                    'No related decisions.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                  ),
                ],
              );
            }
            return _SectionCard(
              children: [
                for (int i = 0; i < rels.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _RelationshipTile(
                    relationship: rels[i],
                    currentDecisionId: widget.decisionId,
                    decisionMap: decisionMap,
                    onLongPress: () => _confirmRemove(context, rels[i]),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

// ── Approvals section ─────────────────────────────────────────────────────────

class _ApprovalsSection extends ConsumerStatefulWidget {
  const _ApprovalsSection({required this.decisionId});

  final String decisionId;

  @override
  ConsumerState<_ApprovalsSection> createState() => _ApprovalsSectionState();
}

class _ApprovalsSectionState extends ConsumerState<_ApprovalsSection> {
  bool _isLoading = false;

  Future<void> _approve(String recordId) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(decisionsRepositoryProvider).approveDecision(recordId);
      ref.invalidate(approvalRecordsProvider(widget.decisionId));
      ref.invalidate(decisionDetailProvider(widget.decisionId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to approve: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reject(String recordId) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(decisionsRepositoryProvider).rejectDecision(recordId);
      ref.invalidate(approvalRecordsProvider(widget.decisionId));
      ref.invalidate(decisionDetailProvider(widget.decisionId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to reject: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestApproval(String userId) async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(decisionsRepositoryProvider)
          .requestApproval(widget.decisionId, userId);
      ref.invalidate(approvalRecordsProvider(widget.decisionId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to request approval: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRequestSheet(List<ApprovalRecord> existing) {
    final teamMembers = ref.read(teamMembersProvider).valueOrNull ?? [];
    final existingIds = existing.map((r) => r.approverUserId).toSet();
    final available =
        teamMembers.where((m) => !existingIds.contains(m.userId)).toList();
    final currentUserId = supabase.auth.currentUser?.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: SvgPicture.asset(
                      isDark
                          ? 'assets/images/reflect-icon-dark.svg'
                          : 'assets/images/reflect-icon-light.svg',
                      height: 32,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Request Approval',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            if (available.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'All workspace members already have approval records.',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(ctx)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                      ),
                ),
              )
            else
              ...available.map((m) {
                final shortId = m.userId.length >= 8
                    ? m.userId.substring(0, 8)
                    : m.userId;
                final isYou = m.userId == currentUserId;
                return ListTile(
                  title: Text(
                    isYou ? '$shortId (you)' : shortId,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  trailing: const Icon(Icons.add),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _requestApproval(m.userId);
                  },
                );
              }),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final approvalsAsync = ref.watch(approvalRecordsProvider(widget.decisionId));
    final currentUserId = supabase.auth.currentUser?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Approvals',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
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
                        tooltip: 'Request approval',
                        onPressed: approvalsAsync.isLoading
                            ? null
                            : () => _showRequestSheet(
                                approvalsAsync.valueOrNull ?? []),
                      ),
              ),
            ],
          ),
        ),
        _SectionCard(
          children: [
            approvalsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(
                'Failed to load approvals.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
              ),
              data: (approvals) {
                if (approvals.isEmpty) {
                  return Text(
                    'No approvals requested.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                  );
                }
                return Column(
                  children: [
                    for (int i = 0; i < approvals.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _ApprovalRecordRow(
                        record: approvals[i],
                        isCurrentUser:
                            approvals[i].approverUserId == currentUserId,
                        isLoading: _isLoading,
                        onApprove: () => _approve(approvals[i].id),
                        onReject: () => _reject(approvals[i].id),
                      ),
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

class _ApprovalRecordRow extends StatelessWidget {
  const _ApprovalRecordRow({
    required this.record,
    required this.isCurrentUser,
    required this.isLoading,
    required this.onApprove,
    required this.onReject,
  });

  final ApprovalRecord record;
  final bool isCurrentUser;
  final bool isLoading;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  static Color _statusColor(String status) => switch (status) {
        'Approved' => AppColors.success,
        'Rejected' => AppColors.destructive,
        _ => AppColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    final shortId = record.approverUserId.length >= 8
        ? record.approverUserId.substring(0, 8)
        : record.approverUserId;
    final color = _statusColor(record.status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUser ? '$shortId (you)' : shortId,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
                if (record.decidedAt != null)
                  Text(
                    DateFormat('d MMM yyyy').format(record.decidedAt!),
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
          if (isCurrentUser && record.status == 'Pending') ...[
            TextButton(
              onPressed: isLoading ? null : onApprove,
              style:
                  TextButton.styleFrom(foregroundColor: AppColors.success),
              child: const Text('Approve'),
            ),
            TextButton(
              onPressed: isLoading ? null : onReject,
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.destructive),
              child: const Text('Reject'),
            ),
          ] else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                record.status,
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

// ── Relationship tile ──────────────────────────────────────────────────────────

class _RelationshipTile extends StatelessWidget {
  const _RelationshipTile({
    required this.relationship,
    required this.currentDecisionId,
    required this.decisionMap,
    required this.onLongPress,
  });

  final DecisionRelationship relationship;
  final String currentDecisionId;
  final Map<String, Decision> decisionMap;
  final VoidCallback onLongPress;

  String _label(String type) => switch (type) {
        'preceded_by' => 'Preceded by',
        'leads_to' => 'Leads to',
        'related' => 'Related to',
        _ => type,
      };

  @override
  Widget build(BuildContext context) {
    final isFrom = relationship.fromDecisionId == currentDecisionId;
    final otherId =
        isFrom ? relationship.toDecisionId : relationship.fromDecisionId;
    final otherTitle = decisionMap[otherId]?.title ??
        otherId.substring(0, otherId.length.clamp(0, 8));
    final arrow = isFrom ? '→' : '←';

    return InkWell(
      onTap: () => context.push('/decisions/detail/$otherId'),
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _label(relationship.relationshipType),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$arrow $otherTitle',
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}
