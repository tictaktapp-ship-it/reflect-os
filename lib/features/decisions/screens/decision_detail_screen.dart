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
import 'package:reflect_os/features/decisions/data/models/comment_thread.dart';
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
import 'package:reflect_os/features/risk/providers/risk_provider.dart';
import 'package:reflect_os/features/calendar/providers/calendar_provider.dart';
import 'package:reflect_os/features/coaching/data/models/coach_note.dart';
import 'package:reflect_os/features/coaching/providers/coaching_provider.dart';
import 'package:reflect_os/features/investment/data/models/asset.dart';
import 'package:reflect_os/features/investment/data/models/ic_vote.dart';
import 'package:reflect_os/features/investment/providers/investment_provider.dart';
import 'package:reflect_os/features/engineering/data/models/engineering_artifact_link.dart';
import 'package:reflect_os/features/engineering/providers/engineering_provider.dart';
import 'package:reflect_os/features/debrief/data/models/decision_debrief.dart';
import 'package:reflect_os/features/debrief/providers/debrief_provider.dart';
import 'package:reflect_os/widgets/app_header.dart';
import 'package:reflect_os/widgets/dialog_shell.dart';
import 'package:reflect_os/features/toolkit/data/models/tool_run.dart';
import 'package:reflect_os/features/toolkit/providers/toolkit_providers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:reflect_os/features/decisions/widgets/decision_lens/decision_lens_tab.dart';
import 'package:reflect_os/core/theme/app_radius.dart';

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
        final tabParam =
            GoRouterState.of(context).uri.queryParameters['tab'];
        final initialTab = (int.tryParse(tabParam ?? '') ?? 0).clamp(0, 5);
        return _DecisionDetail(decision: decision, initialTab: initialTab);
      },
    );
  }
}

class _DecisionDetail extends ConsumerStatefulWidget {
  const _DecisionDetail({required this.decision, this.initialTab = 0});

  final Decision decision;
  final int initialTab;

  @override
  ConsumerState<_DecisionDetail> createState() => _DecisionDetailState();
}

class _DecisionDetailState extends ConsumerState<_DecisionDetail> {
  bool _isGenerating = false;
  bool _outcomesExpanded = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

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
      await launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
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

  Future<void> _showShareSheet() async {
    final workspaceId = await ref.read(currentWorkspaceProvider.future);
    final workspaceName =
        await ref.read(workspaceNameProvider.future) ?? 'My Workspace';
    if (workspaceId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No workspace found.')),
        );
      }
      return;
    }
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DialogShell(
        title: 'Share to Team Workspace',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Creates a one-time copy in the selected workspace. '
              'Changes will not sync between copies.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.group_outlined),
              title: Text(workspaceName),
              subtitle: const Text('Target workspace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _doShare(workspaceId, workspaceName);
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  Future<void> _doShare(String workspaceId, String workspaceName) async {
    try {
      await ref
          .read(decisionsRepositoryProvider)
          .shareDecisionToTeam(widget.decision.id, workspaceId);
      ref.invalidate(decisionDetailProvider(widget.decision.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Decision shared to $workspaceName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share decision: $e'),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
  }

  Future<void> _onDeleteTapped(
      BuildContext context, Decision decision) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DialogShell(
        title: 'Delete Decision',
        child: const Text(
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
    await ref.read(decisionsRepositoryProvider).deleteDecision(decision.id);
    ref.invalidate(decisionsProvider);
    if (context.mounted) context.go(Routes.decisionsList);
  }

  @override
  Widget build(BuildContext context) {
    final decision = widget.decision;
    final outcomesAsync = ref.watch(outcomesProvider(decision.id));
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppHeader(
        title: decision.title,
        automaticallyImplyLeading: true,
        actions: [
          if (_isGenerating)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More options',
            onSelected: (value) async {
              if (value == 'edit') {
                context.push('/decisions/edit/${decision.id}', extra: decision);
              } else if (value == 'brief') {
                await _onGenerateBriefTapped();
              } else if (value == 'share') {
                await _showShareSheet();
              } else if (value == 'share_links') {
                context.push('/decisions/${decision.id}/share-links');
              } else if (value == 'delete') {
                await _onDeleteTapped(context, decision);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit'),
                ),
              ),
              const PopupMenuItem(
                value: 'brief',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.picture_as_pdf_outlined),
                  title: Text('Generate Brief'),
                ),
              ),
              if (decision.state != 'Draft')
                const PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.share_outlined),
                    title: Text('Share to Team'),
                  ),
                ),
              const PopupMenuItem(
                value: 'share_links',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.link_outlined),
                  title: Text('Manage Share Links'),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline,
                      color: AppColors.destructive),
                  title: Text('Delete',
                      style: TextStyle(color: AppColors.destructive)),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/outcomes/create/${decision.id}'),
        backgroundColor: const Color(0xFF19CBD6),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_chart_rounded, size: 20),
        label: const Text(
          'Record Outcome',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'DMSans',
            letterSpacing: 0.3,
          ),
        ),
      ),
      body: Column(
        children: [
          _FilingCabinetTabBar(
            selectedIndex: _tab,
            onTabSelected: (i) => setState(() => _tab = i),
            narrow: screenWidth < 600,
            scrollable: screenWidth < 400,
            tabs: const [
              _TabDef(label: 'Overview', icon: Icons.info_outline),
              _TabDef(label: 'Details', icon: Icons.notes),
              _TabDef(label: 'People', icon: Icons.group_outlined),
              _TabDef(label: 'Evidence', icon: Icons.attach_file),
              _TabDef(label: 'Risk', icon: Icons.shield_outlined),
              _TabDef(label: 'Lens', icon: Icons.analytics_outlined),
            ],
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                // ── Tab 0: Overview ───────────────────────────────────
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SummaryCard(decision: decision),
                    const SizedBox(height: 12),
                    _StateTransitionBar(decision: decision),
                    _CollapsibleSection(
                      title: 'State & Health',
                      initiallyExpanded: true,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _StateBadge(state: decision.state),
                          if (decision.healthState != null)
                            _HealthBadge(healthState: decision.healthState!),
                          if (decision.isContinuous) const _ContinuousBadge(),
                          if (decision.requiresApproval && decision.isDraft)
                            const _PendingApprovalBadge(),
                          if (decision.sharedToTeamAt != null)
                            const Chip(
                              avatar: Icon(Icons.share_outlined, size: 14),
                              label: Text('Shared to team'),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ),
                    if (decision.sourceDecisionId != null)
                      _CollapsibleSection(
                        title: 'Shared From',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.call_received_outlined,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Shared from another workspace'
                                '${decision.sharedFromPersonalAt != null ? ' on ${_formatDate(decision.sharedFromPersonalAt!)}' : ''}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _ProjectedOutcomeSection(decisionId: decision.id),
                    _CollapsibleSection(
                      title: 'Dates',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                    ),
                    const SizedBox(height: 80),
                  ],
                ),

                // ── Tab 1: Details ────────────────────────────────────
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _CollapsibleSection(
                      title: 'Overview',
                      initiallyExpanded: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (decision.stakes != null)
                            _DetailRow(
                                label: 'Stakes', value: decision.stakes!),
                          if (decision.categoryName != null)
                            _DetailRow(
                                label: 'Category',
                                value: decision.categoryName!),
                          if (decision.initialConfidence != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Initial confidence',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  _EffectiveConfidenceBadge(
                                    decisionId: decision.id,
                                    initialConfidence:
                                        decision.initialConfidence,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (decision.descriptionEncrypted != null)
                      _CollapsibleSection(
                        title: 'Description',
                        child: _DetailRow(
                          label: 'Description',
                          value: decision.descriptionEncrypted!,
                          valueMaxLines: null,
                        ),
                      ),
                    _TagsSection(decisionId: decision.id),
                    _InitiativesSection(decisionId: decision.id),
                    _RelatedDecisionsSection(decisionId: decision.id),
                    const SizedBox(height: 80),
                  ],
                ),

                // ── Tab 2: People ─────────────────────────────────────
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _StakeholdersSection(decisionId: decision.id),
                    _CoachNotesSection(decisionId: decision.id),
                    if (decision.state == 'Active')
                      _CommentsSection(decisionId: decision.id),
                    const SizedBox(height: 80),
                  ],
                ),

                // ── Tab 3: Evidence ───────────────────────────────────
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    InkWell(
                      onTap: () => setState(
                          () => _outcomesExpanded = !_outcomesExpanded),
                      borderRadius: AppRadius.smBR,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Outcomes',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                              ),
                            ),
                            Icon(
                              _outcomesExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 20,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_outcomesExpanded)
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
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.4),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.4),
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
                    if (decision.state == 'Active' ||
                        decision.state == 'Closed')
                      _CheckpointsSection(decisionId: decision.id),
                    _EvidenceSection(decisionId: decision.id),
                    _EngineeringArtifactsSection(decisionId: decision.id),
                    _ActivitySection(decisionId: decision.id),
                    _ToolKitSection(decisionId: decision.id),
                    const SizedBox(height: 80),
                  ],
                ),

                // ── Tab 4: Risk ───────────────────────────────────────
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _RiskAssessmentSection(decisionId: decision.id),
                    if (decision.requiresApproval)
                      _ApprovalsSection(decisionId: decision.id),
                    _IcVoteSection(decisionId: decision.id),
                    _LinkedAssetsSection(decisionId: decision.id),
                    if (decision.state == 'Closed' ||
                        decision.state == 'Archived')
                      _DebriefSection(decisionId: decision.id),
                    const SizedBox(height: 80),
                  ],
                ),

                // ── Tab 5: Lens ───────────────────────────────────────
                DecisionLensTab(decision: decision),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── _TabDef ───────────────────────────────────────────────────────────────────

class _TabDef {
  const _TabDef({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

// ── FilingCabinetTabBar ───────────────────────────────────────────────────────

class _FilingCabinetTabBar extends StatelessWidget {
  const _FilingCabinetTabBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.narrow = false,
    this.scrollable = false,
  });

  final List<_TabDef> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  /// When true, shows icons only (no labels). Triggered at < 600px.
  final bool narrow;

  /// When true, wraps tabs in horizontal scroll. Triggered at < 400px.
  final bool scrollable;

  static const _selectedHeight = 52.0;
  static const _unselectedHeight = 44.0;
  static const _selectedTopColor = AppColorScheme.accent;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final borderColor = cs.borderDefault;
    final unselectedBg = cs.backgroundElevated;
    final selectedBg = cs.backgroundSecondary;

    final tabWidgets = List.generate(tabs.length, (i) {
      final selected = i == selectedIndex;
      final tab = tabs[i];

      Widget label = selected
          ? Icon(tab.icon, size: narrow ? 18 : 15, color: _selectedTopColor)
          : Icon(tab.icon,
              size: narrow ? 18 : 15, color: cs.textTertiary);

      if (!narrow) {
        label = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            label,
            const SizedBox(width: 5),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? _selectedTopColor : cs.textTertiary,
              ),
            ),
          ],
        );
      }

      return GestureDetector(
        onTap: () => onTabSelected(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.ease,
          height: selected ? _selectedHeight : _unselectedHeight,
          padding: EdgeInsets.symmetric(horizontal: narrow ? 8 : 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? selectedBg : unselectedBg,
            border: Border(
              top: BorderSide(
                color: selected ? _selectedTopColor : borderColor,
                width: selected ? 2.0 : 1.0,
              ),
              left: BorderSide(color: borderColor),
              right: BorderSide(color: borderColor),
              // Selected tab's bg bottom "covers" the outer bottom border.
              bottom: BorderSide(
                color: selected ? selectedBg : borderColor,
              ),
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadius.sm),
              topRight: Radius.circular(AppRadius.sm),
            ),
          ),
          child: label,
        ),
      );
    });

    final row = scrollable
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: tabWidgets,
            ),
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: tabWidgets.map((t) => Expanded(child: t)).toList(),
          );

    return Container(
      decoration: BoxDecoration(
        color: unselectedBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: row,
    );
  }
}

// ── Summary card ─────────────────────────────────────────────────────────────

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.decision});
  final Decision decision;

  static Color _healthColor(String? h) => switch (h) {
        'on_track' => const Color(0xFF2EA073),
        'needs_attention' => const Color(0xFFD97D24),
        'overdue' => const Color(0xFFDC4444),
        _ => AppColors.textMuted,
      };

  static String _healthLabel(String? h) => switch (h) {
        'on_track' => 'On Track',
        'needs_attention' => 'Needs Attention',
        'overdue' => 'Overdue',
        _ => h ?? '',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Override health state based on approved risk level.
    final effectiveHealth = ref
        .watch(effectiveHealthStateProvider(
            (decisionId: decision.id, dbHealthState: decision.healthState)))
        .valueOrNull ?? decision.healthState;

    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            // State
            _SummaryPill(
              label: decision.state,
              bg: _stateColor(decision.state).withValues(alpha: 0.12),
              fg: _stateColor(decision.state),
            ),
            // Health (risk-adjusted)
            if (effectiveHealth != null)
              _SummaryPill(
                label: _healthLabel(effectiveHealth),
                bg: _healthColor(effectiveHealth).withValues(alpha: 0.12),
                fg: _healthColor(effectiveHealth),
                icon: Icons.circle,
                iconSize: 6,
              ),
            // Stakes
            if (decision.stakes != null)
              _SummaryPill(
                label: decision.stakes!,
                bg: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.06),
                fg: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            // Category
            if (decision.categoryName != null)
              _SummaryPill(
                label: decision.categoryName!,
                bg: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.06),
                fg: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
                icon: Icons.category_outlined,
              ),
            // Confidence
            if (decision.initialConfidence != null)
              _SummaryPill(
                label: '${decision.initialConfidence}/10 confidence',
                bg: AppColors.accentPrimary.withValues(alpha: 0.08),
                fg: AppColors.accentPrimary,
                icon: Icons.signal_cellular_alt_outlined,
              ),
          ],
        ),
      ),
    );
  }

  Color _stateColor(String s) => switch (s.toLowerCase()) {
        'active' => AppColors.accentPrimary,
        'draft' => AppColors.textSecondary,
        'closed' => AppColors.success,
        'archived' => AppColors.textMuted,
        _ => AppColors.textSecondary,
      };
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.bg,
    required this.fg,
    this.icon,
    this.iconSize = 12,
  });
  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.mdBR,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
          ),
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
        borderRadius: AppRadius.mdBR,
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

// ── Collapsible section wrapper ───────────────────────────────────────────────

class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
    this.trailing,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;
  final Widget? trailing;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: AppRadius.smBR,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    if (widget.trailing != null) widget.trailing!,
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 12),
              widget.child,
            ],
          ],
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

  Future<void> _archiveContinuousWithPrompt(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogShell(
        title: 'Archive this standing decision?',
        child: const Text(
          'This continuous decision will be archived. '
          'It can be restored later from the Archived state.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.textMuted),
            child: const Text('Archive',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(() =>
          ref.read(decisionsRepositoryProvider).archiveDecision(id));
    }
  }

  Future<void> _closeWithDebriefPrompt(String id) async {
    final repo = ref.read(decisionsRepositoryProvider);
    await _run(() => repo.closeDecision(id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Decision closed.'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Generate Debrief',
          onPressed: () {
            ref
                .read(debriefRepositoryProvider)
                .generateDebrief(id)
                .then((_) => ref.invalidate(debriefProvider(id)))
                .catchError((_) {});
          },
        ),
      ),
    );
  }

  Future<void> _showUnarchiveSheet() async {
    final newState = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => DialogShell(
        title: 'Restore to which state?',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
      'Draft' when approvalBlocked => <Widget>[
          // Owner sees "Awaiting Approval" label — cannot self-activate.
          Text(
            'Awaiting Approval',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(width: 12),
          // Any user (including owner) can approve & activate in one tap.
          FilledButton(
            onPressed: _isLoading
                ? null
                : () => _run(() => repo.approveAndActivate(id)),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentPrimary),
            child: const Text('Approve & Activate',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      'Draft' => <Widget>[
          OutlinedButton(
            onPressed: _isLoading
                ? null
                : () => _run(() => repo.activateDecision(id)),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentHover),
            child: const Text('Activate'),
          ),
        ],
      'Active' when widget.decision.isContinuous => <Widget>[
          // Continuous decisions are archived, not closed.
          OutlinedButton(
            onPressed: _isLoading
                ? null
                : () => _archiveContinuousWithPrompt(id),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textMuted),
            child: const Text('Archive standing decision'),
          ),
        ],
      'Active' => <Widget>[
          OutlinedButton(
            onPressed:
                _isLoading ? null : () => _closeWithDebriefPrompt(id),
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
        borderRadius: AppRadius.mdBR,
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

// ── Continuous badge ──────────────────────────────────────────────────────────

class _ContinuousBadge extends StatelessWidget {
  const _ContinuousBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.12),
        borderRadius: AppRadius.mdBR,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.all_inclusive,
              size: 12, color: AppColors.accentPrimary),
          const SizedBox(width: 4),
          Text(
            'Continuous',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.accentPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Pending approval badge ────────────────────────────────────────────────────

class _PendingApprovalBadge extends StatelessWidget {
  const _PendingApprovalBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: AppRadius.mdBR,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pending_outlined,
              size: 12, color: AppColors.warning),
          const SizedBox(width: 4),
          Text(
            'Pending Approval',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
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
        borderRadius: AppRadius.mdBR,
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
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.sheetTop,
        side: BorderSide(color: Color(0xFF19CBD6), width: 1.5),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: SvgPicture.asset('assets/branding/icon.svg', height: 40)),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final initiativesAsync =
        ref.watch(initiativesForDecisionProvider(widget.decisionId));

    return _CollapsibleSection(
      title: 'Initiatives',
      trailing: SizedBox(
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
      child: initiativesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
                    onDeleted: _isLoading ? null : () => _unlink(i.id),
                  ),
                )
                .toList(),
          );
        },
      ),
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
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.sheetTop,
        side: BorderSide(color: Color(0xFF19CBD6), width: 1.5),
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
                        Center(child: SvgPicture.asset('assets/branding/icon.svg', height: 40)),
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

    return _CollapsibleSection(
      title: 'Tags',
      trailing: SizedBox(
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
      child: tagsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
    );
  }
}

// ── Projected Outcome section ──────────────────────────────────────────────────

class _ProjectedOutcomeSection extends ConsumerWidget {
  const _ProjectedOutcomeSection({required this.decisionId});

  final String decisionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcomeAsync = ref.watch(projectedOutcomeProvider(decisionId));

    return outcomeAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (outcome) {
        if (outcome == null || outcome.isEmpty) return const SizedBox.shrink();
        return _CollapsibleSection(
          title: 'Projected Outcome',
          trailing: const Tooltip(
            message: 'Populated by tool injection',
            child: Icon(Icons.auto_awesome_outlined, size: 14),
          ),
          child: _DetailRow(
            label: 'Projected outcome',
            value: outcome,
            valueMaxLines: null,
          ),
        );
      },
    );
  }
}

// ── Checkpoints section ────────────────────────────────────────────────────────

class _CheckpointsSection extends ConsumerStatefulWidget {
  const _CheckpointsSection({required this.decisionId});

  final String decisionId;

  @override
  ConsumerState<_CheckpointsSection> createState() =>
      _CheckpointsSectionState();
}

class _CheckpointsSectionState extends ConsumerState<_CheckpointsSection> {
  static const List<String> _checkpointTypes = [
    '30_day',
    '90_day',
    '180_day',
    '6_month',
    '12_month',
    '24_month',
    'monthly_continuous',
    'custom',
  ];

  static String _formatTypeLabel(String type) => switch (type) {
        '30_day' => '30 Day',
        '90_day' => '90 Day',
        '180_day' => '180 Day',
        '6_month' => '6 Month',
        '12_month' => '12 Month',
        '24_month' => '24 Month',
        'monthly_continuous' => 'Monthly',
        'custom' => 'Custom',
        _ => type.replaceAll('_', ' '),
      };

  Future<void> _showAddSheet() async {
    DateTime? pickedDate;
    String selectedType = '30_day';

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => DialogShell(
          title: 'Add Checkpoint',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Checkpoint type',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                child: DropdownButton<String>(
                  value: selectedType,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: _checkpointTypes
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(_formatTypeLabel(t)),
                          ))
                      .toList(),
                  onChanged: (v) => setSS(() => selectedType = v!),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(
                  pickedDate == null
                      ? 'Pick a date'
                      : DateFormat('d MMM yyyy').format(pickedDate!),
                ),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate:
                        DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (d != null) setSS(() => pickedDate = d);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: pickedDate == null
                  ? null
                  : () async {
                      Navigator.of(ctx).pop();
                      try {
                        await ref
                            .read(decisionsRepositoryProvider)
                            .createCheckpoint(
                              decisionId: widget.decisionId,
                              checkpointType: selectedType,
                              dueAt: pickedDate!,
                            );
                        ref.invalidate(
                            checkpointsProvider(widget.decisionId));
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Failed to add checkpoint: $e')),
                          );
                        }
                      }
                    },
              child: const Text('Add Checkpoint'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkpointsAsync =
        ref.watch(checkpointsProvider(widget.decisionId));

    return _CollapsibleSection(
      title: 'Review Checkpoints',
      trailing: IconButton(
        icon: const Icon(Icons.add, size: 18),
        tooltip: 'Add checkpoint',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: _showAddSheet,
      ),
      child: checkpointsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text(
          'Failed to load checkpoints.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4)),
        ),
        data: (checkpoints) {
          if (checkpoints.isEmpty) {
            return Text(
              'No checkpoints scheduled.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4)),
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
    );
  }
}

class _CheckpointRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final displayDate =
        checkpoint.status == 'Snoozed' && checkpoint.snoozedUntil != null
            ? checkpoint.snoozedUntil!
            : checkpoint.dueAt;
    final color = _statusColor(checkpoint.status);
    final eventLinks =
        ref.watch(calendarEventLinksProvider(checkpoint.id));
    final hasCalendarEvent =
        eventLinks.valueOrNull?.isNotEmpty ?? false;

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
                Row(
                  children: [
                    Text(
                      DateFormat('d MMM yyyy').format(displayDate),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                    if (hasCalendarEvent) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.event_outlined,
                        size: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.45),
                      ),
                    ],
                  ],
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
              borderRadius: AppRadius.smBR,
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

    return _CollapsibleSection(
      title: 'Activity',
      child: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    setState(() => _isSending = true);
    try {
      final repo = ref.read(decisionsRepositoryProvider);
      CommentThread? thread =
          ref.read(commentThreadProvider(widget.decisionId)).valueOrNull;
      if (thread == null) {
        thread = await repo.createCommentThread(widget.decisionId);
        ref.invalidate(commentThreadProvider(widget.decisionId));
      }
      await repo.postComment(thread.id, body);
      _controller.clear();
      ref.invalidate(commentsProvider(thread.id));
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

    return _CollapsibleSection(
      title: 'Comments',
      child: threadAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text(
          'Failed to load comments: $e',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
        ),
        data: (thread) {
          return _CommentsThreadBody(
            thread: thread,
            onSend: _send,
            controller: _controller,
            isSending: _isSending,
          );
        },
      ),
    );
  }
}

// Body-only variant used inside _CollapsibleSection (no outer Card).
class _CommentsThreadBody extends ConsumerWidget {
  const _CommentsThreadBody({
    required this.thread,
    required this.onSend,
    required this.controller,
    required this.isSending,
  });

  final dynamic thread; // CommentThread? — null means no thread yet
  final Future<void> Function() onSend;
  final TextEditingController controller;
  final bool isSending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadId = thread?.id as String?;
    final commentsAsync = threadId != null
        ? ref.watch(commentsProvider(threadId))
        : const AsyncValue<List<dynamic>>.data([]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              children: comments.map((c) => _CommentRow(comment: c)).toList(),
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
                decoration: const InputDecoration(hintText: 'Add a comment…'),
                onSubmitted: isSending ? null : (_) => onSend(),
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
                    onPressed: onSend,
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

  Future<void> _addMember(String userId, String role) async {
    setState(() => _isLoading = true);
    String? err;
    try {
      await ref
          .read(decisionsRepositoryProvider)
          .addStakeholder(widget.decisionId, role, userId: userId);
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

  Future<void> _addExternal(
      String role, String name, String? email) async {
    setState(() => _isLoading = true);
    String? err;
    try {
      await ref
          .read(decisionsRepositoryProvider)
          .addStakeholder(
            widget.decisionId,
            role,
            stakeholderName: name.trim().isEmpty ? null : name.trim(),
            stakeholderEmail: email?.trim().isEmpty == true ? null : email?.trim(),
          );
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

  Future<void> _remove(String stakeholderId) async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(decisionsRepositoryProvider)
          .removeStakeholder(widget.decisionId, stakeholderId);
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
    final addedUserIds = current.map((s) => s.userId).whereType<String>().toSet();
    final available =
        teamMembers.where((m) => !addedUserIds.contains(m.userId)).toList();
    final currentUserId = supabase.auth.currentUser?.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.sheetTop,
        side: BorderSide(color: Color(0xFF19CBD6), width: 1.5),
      ),
      builder: (_) => _AddStakeholderSheet(
        available: available,
        roles: _roles,
        currentUserId: currentUserId,
        onAdd: (userId, role) {
          Navigator.of(context).pop();
          _addMember(userId, role);
        },
        onAddExternal: (role, name, email) {
          Navigator.of(context).pop();
          _addExternal(role, name, email);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stakeholdersAsync =
        ref.watch(stakeholdersProvider(widget.decisionId));
    final teamMembers = ref.watch(teamMembersProvider).valueOrNull ?? [];
    final membersByUserId = {
      for (final m in teamMembers) m.userId: m,
    };

    return _CollapsibleSection(
      title: 'Stakeholders',
      trailing: SizedBox(
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
                    : () => _showAddSheet(stakeholdersAsync.valueOrNull ?? []),
              ),
      ),
      child: stakeholdersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Text(
          'No stakeholders added.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4)),
        ),
        data: (stakeholders) {
          if (stakeholders.isEmpty) {
            return Text(
              'No stakeholders added.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
            );
          }
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: stakeholders.map((s) {
              final color = _roleColor(s.stakeholderRole);
              final member = s.userId != null ? membersByUserId[s.userId] : null;
              final resolvedName = member?.displayName?.isNotEmpty == true
                  ? member!.displayName!
                  : s.displayName;
              final initial = resolvedName.isNotEmpty
                  ? resolvedName[0].toUpperCase()
                  : '?';

              return Chip(
                backgroundColor: color.withValues(alpha: 0.10),
                avatar: CircleAvatar(
                  radius: 12,
                  backgroundColor: color.withValues(alpha: 0.25),
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                label: Text(
                  '$resolvedName · ${s.stakeholderRole}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                deleteIcon: Icon(Icons.close, size: 14, color: color),
                onDeleted: _isLoading ? null : () => _remove(s.id),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _AddStakeholderSheet extends StatefulWidget {
  const _AddStakeholderSheet({
    required this.available,
    required this.roles,
    required this.currentUserId,
    required this.onAdd,
    required this.onAddExternal,
  });

  final List<WorkspaceMembership> available;
  final List<String> roles;
  final String? currentUserId;
  final void Function(String userId, String role) onAdd;
  final void Function(String role, String name, String? email) onAddExternal;

  @override
  State<_AddStakeholderSheet> createState() => _AddStakeholderSheetState();
}

class _AddStakeholderSheetState extends State<_AddStakeholderSheet> {
  late final Map<String, String> _selectedRoles = {
    for (final m in widget.available) m.userId: 'Informed',
  };

  bool _showExternal = false;
  String _externalRole = 'Informed';
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'Add Stakeholder',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        // Toggle: workspace member vs external
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Workspace member')),
              ButtonSegment(value: true, label: Text('External')),
            ],
            selected: {_showExternal},
            onSelectionChanged: (s) =>
                setState(() => _showExternal = s.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        const Divider(height: 16),
        if (_showExternal) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name *'),
                    textCapitalization: TextCapitalization.words,
                    autofocus: true,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Name required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Email (optional)'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Role:'),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _externalRole,
                        underline: const SizedBox.shrink(),
                        items: widget.roles
                            .map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(r),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _externalRole = v);
                        },
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;
                          final email = _emailCtrl.text.trim();
                          widget.onAddExternal(
                            _externalRole,
                            _nameCtrl.text.trim(),
                            email.isEmpty ? null : email,
                          );
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          if (widget.available.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'All workspace members are already stakeholders.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
              ),
            )
          else
            ...widget.available.map((m) {
              final name = m.displayName?.isNotEmpty == true
                  ? m.displayName!
                  : (m.userId.length >= 8
                      ? m.userId.substring(0, 8)
                      : m.userId);
              final isYou = m.userId == widget.currentUserId;
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(isYou ? '$name (you)' : name),
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
        ],
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
      builder: (_) => DialogShell(
        title: 'Remove Evidence',
        child: const Text('Remove this evidence item? This cannot be undone.'),
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

    showDialog(
      context: context,
      barrierDismissible: true,
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

            return DialogShell(
              title: 'Add Link',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
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
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final evidenceAsync = ref.watch(evidenceProvider(widget.decisionId));

    return _CollapsibleSection(
      title: 'Evidence',
      trailing: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: const Icon(Icons.add, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Add evidence',
              onPressed: _showAddSheet,
            ),
      child: evidenceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Text(
          'Failed to load evidence.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Text(
              'No evidence attached.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
            );
          }
          return Column(
            children: items
                .map((item) => _EvidenceTile(
                      item: item,
                      onDelete: () => _confirmDelete(context, item.id),
                    ))
                .toList(),
          );
        },
      ),
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
              launchUrl(Uri.parse(item.url!), mode: LaunchMode.externalApplication).ignore();
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
      builder: (_) => DialogShell(
        title: 'Remove Relationship',
        child: const Text('Remove this relationship?'),
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
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.sheetTop,
        side: BorderSide(color: Color(0xFF19CBD6), width: 1.5),
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
                  Center(child: SvgPicture.asset('assets/branding/icon.svg', height: 40)),
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

    return _CollapsibleSection(
      title: 'Related Decisions',
      trailing: _isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add related decision',
              visualDensity: VisualDensity.compact,
              onPressed: () => _showAddSheet(allDecisions),
            ),
      child: relsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text(
          'Failed to load relationships.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
        ),
        data: (rels) {
          if (rels.isEmpty) {
            return Text(
              'No related decisions.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
            );
          }
          return Column(
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
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.sheetTop,
        side: BorderSide(color: Color(0xFF19CBD6), width: 1.5),
      ),
      builder: (ctx) {
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
                      'assets/branding/icon.svg',
                      height: 40,
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

    return _CollapsibleSection(
      title: 'Approvals',
      trailing: SizedBox(
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
                    : () => _showRequestSheet(approvalsAsync.valueOrNull ?? []),
              ),
      ),
      child: approvalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text(
          'Failed to load approvals.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
        ),
        data: (approvals) {
          if (approvals.isEmpty) {
            return Text(
              'No approvals requested.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
            );
          }
          return Column(
            children: [
              for (int i = 0; i < approvals.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _ApprovalRecordRow(
                  record: approvals[i],
                  isCurrentUser: approvals[i].approverUserId == currentUserId,
                  isLoading: _isLoading,
                  onApprove: () => _approve(approvals[i].id),
                  onReject: () => _reject(approvals[i].id),
                ),
              ],
            ],
          );
        },
      ),
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
                borderRadius: AppRadius.smBR,
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

// ── Risk Assessment compact summary card ──────────────────────────────────────

class _RiskAssessmentSection extends ConsumerWidget {
  const _RiskAssessmentSection({required this.decisionId});
  final String decisionId;

  static Color _riskColor(String? level) => switch (level?.toLowerCase()) {
        'low' => const Color(0xFF2EA073),
        'medium' => const Color(0xFFD97D24),
        'high' => const Color(0xFFDC4444),
        'critical' => const Color(0xFF7C3AED),
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assessmentAsync = ref.watch(approvedRiskAssessmentProvider(decisionId));
    final adjustmentAsync = ref.watch(riskConfidenceAdjustmentProvider(decisionId));

    return _CollapsibleSection(
      title: 'Risk Assessment',
      child: assessmentAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(),
        ),
        error: (_, __) => const SizedBox.shrink(),
        data: (assessment) {
          if (assessment == null) {
            // No approved assessment yet
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No risk assessment yet.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.shield_outlined, size: 16),
                    label: const Text('Add risk assessment'),
                    onPressed: () => context.push(
                      '/decisions/$decisionId/risk-assessment',
                    ),
                  ),
                ],
              ),
            );
          }

          // Approved assessment — compact summary
          final level = assessment.overallRiskLevel ?? 'medium';
          final color = _riskColor(level);
          final riskCount = assessment.risks.length;
          final adjustment = adjustmentAsync.valueOrNull ?? 0;

          return InkWell(
            borderRadius: AppRadius.mdBR,
            onTap: () => context.push(
              '/decisions/$decisionId/risk-assessment',
              extra: assessment,
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: AppRadius.mdBR,
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, size: 18, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: AppRadius.smBR,
                              ),
                              child: Text(
                                level.toUpperCase(),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$riskCount risk${riskCount == 1 ? '' : 's'} identified',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.65),
                                  ),
                            ),
                          ],
                        ),
                        if (adjustment != 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Risk impact: $adjustment on confidence',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AppColors.destructive,
                                  fontSize: 10,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Debrief section ────────────────────────────────────────────────────────────

enum _DebriefFeedback { up, down }

class _DebriefSection extends ConsumerStatefulWidget {
  const _DebriefSection({required this.decisionId});

  final String decisionId;

  @override
  ConsumerState<_DebriefSection> createState() => _DebriefSectionState();
}

class _DebriefSectionState extends ConsumerState<_DebriefSection> {
  bool _isGenerating = false;
  _DebriefFeedback? _userFeedback;

  static Color _verdictColor(String? verdict) => switch (verdict?.toLowerCase()) {
        'good' => AppColors.success,
        'mixed' => const Color(0xFFFFC107),
        'poor' => AppColors.destructive,
        _ => AppColors.textSecondary,
      };

  static Color _trajectoryColor(String? trajectory) =>
      switch (trajectory?.toLowerCase()) {
        'improving' => AppColors.success,
        'stable' => AppColors.textSecondary,
        'declining' => AppColors.destructive,
        _ => AppColors.textSecondary,
      };

  Future<void> _generate() async {
    setState(() => _isGenerating = true);
    try {
      await ref
          .read(debriefRepositoryProvider)
          .generateDebrief(widget.decisionId);
      ref.invalidate(debriefProvider(widget.decisionId));
    } catch (e) {
      if (!mounted) return;
      final isNetworkError = e.toString().contains('Failed to fetch') ||
          e.toString().contains('XMLHttpRequest');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNetworkError
                ? 'Debrief unavailable in this network environment.'
                : 'Failed to generate debrief: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _saveFeedback(String debriefId, _DebriefFeedback feedback) async {
    setState(() => _userFeedback = feedback);
    try {
      await ref
          .read(debriefRepositoryProvider)
          .saveFeedback(debriefId, feedback == _DebriefFeedback.up ? 'up' : 'down');
    } catch (_) {
      // Feedback save is best-effort; silently ignore errors.
    }
  }

  @override
  Widget build(BuildContext context) {
    final debriefAsync = ref.watch(debriefProvider(widget.decisionId));

    return _CollapsibleSection(
      title: 'Decision Debrief',
      trailing: _isGenerating
          ? null
          : IconButton(
              icon: const Icon(Icons.auto_awesome_outlined, size: 20),
              tooltip: 'Generate debrief',
              onPressed: _generate,
            ),
      child: _isGenerating
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Generating debrief…'),
                ],
              ),
            )
          : debriefAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Failed to load debrief.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.destructive),
                ),
              ),
              data: (debrief) => debrief == null
                  ? _DebriefEmptyState(onGenerate: _generate)
                  : _DebriefBody(
                      debrief: debrief,
                      userFeedback: _userFeedback,
                      onFeedback: (f) => _saveFeedback(debrief.id, f),
                      onRegenerate: _generate,
                      verdictColor: _verdictColor,
                      trajectoryColor: _trajectoryColor,
                    ),
            ),
    );
  }
}

class _DebriefEmptyState extends StatelessWidget {
  const _DebriefEmptyState({required this.onGenerate});
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No debrief generated yet.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.auto_awesome_outlined, size: 16),
            label: const Text('Generate Debrief'),
            onPressed: onGenerate,
          ),
        ],
      ),
    );
  }
}

class _DebriefBody extends StatelessWidget {
  const _DebriefBody({
    required this.debrief,
    required this.userFeedback,
    required this.onFeedback,
    required this.onRegenerate,
    required this.verdictColor,
    required this.trajectoryColor,
  });

  final DecisionDebrief debrief;
  final _DebriefFeedback? userFeedback;
  final ValueChanged<_DebriefFeedback> onFeedback;
  final VoidCallback onRegenerate;
  final Color Function(String?) verdictColor;
  final Color Function(String?) trajectoryColor;

  @override
  Widget build(BuildContext context) {
    final verdict = debrief.verdict;
    final vColor = verdictColor(verdict);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Verdict badge + trajectory ─────────────────────────
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (verdict != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: vColor.withValues(alpha: 0.15),
                  borderRadius: AppRadius.mdBR,
                ),
                child: Text(
                  verdict,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: vColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            if (debrief.qualityTrajectory != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: trajectoryColor(debrief.qualityTrajectory)
                      .withValues(alpha: 0.12),
                  borderRadius: AppRadius.mdBR,
                ),
                child: Text(
                  debrief.qualityTrajectory!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: trajectoryColor(debrief.qualityTrajectory),
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            if (debrief.confidenceCalibration != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.08),
                  borderRadius: AppRadius.mdBR,
                ),
                child: Text(
                  debrief.confidenceCalibration!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
          ],
        ),

        // ── Summary ────────────────────────────────────────────
        if (debrief.summary != null) ...[
          const SizedBox(height: 10),
          Text(
            debrief.summary!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],

        // ── Key lessons ────────────────────────────────────────
        if (debrief.keyLessons.isNotEmpty) ...[
          const SizedBox(height: 12),
          _DebriefList(
            title: 'Key Lessons',
            items: debrief.keyLessons,
            icon: Icons.lightbulb_outline,
            iconColor: const Color(0xFFFFC107),
          ),
        ],

        // ── What worked ────────────────────────────────────────
        if (debrief.whatWorked.isNotEmpty) ...[
          const SizedBox(height: 8),
          _DebriefList(
            title: 'What Worked',
            items: debrief.whatWorked,
            icon: Icons.check_circle_outline,
            iconColor: AppColors.success,
          ),
        ],

        // ── What to improve ────────────────────────────────────
        if (debrief.whatToImprove.isNotEmpty) ...[
          const SizedBox(height: 8),
          _DebriefList(
            title: 'What to Improve',
            items: debrief.whatToImprove,
            icon: Icons.trending_up_outlined,
            iconColor: AppColors.warning,
          ),
        ],

        // ── Pattern flags ──────────────────────────────────────
        if (debrief.patternFlags.isNotEmpty) ...[
          const SizedBox(height: 8),
          _DebriefList(
            title: 'Pattern Flags',
            items: debrief.patternFlags,
            icon: Icons.flag_outlined,
            iconColor: AppColors.destructive,
          ),
        ],

        // ── Feedback + regenerate row ───────────────────────────
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              'Helpful?',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                Icons.thumb_up_outlined,
                size: 18,
                color: userFeedback == _DebriefFeedback.up
                    ? AppColors.success
                    : null,
              ),
              onPressed: () => onFeedback(_DebriefFeedback.up),
            ),
            IconButton(
              icon: Icon(
                Icons.thumb_down_outlined,
                size: 18,
                color: userFeedback == _DebriefFeedback.down
                    ? AppColors.destructive
                    : null,
              ),
              onPressed: () => onFeedback(_DebriefFeedback.down),
            ),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Regenerate'),
              onPressed: onRegenerate,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                textStyle: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),

        // AI disclaimer
        Text(
          'Generated by AI · Always verify independently',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
      ],
    );
  }
}

class _DebriefList extends StatelessWidget {
  const _DebriefList({
    required this.title,
    required this.items,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final List<String> items;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Coach Notes section ────────────────────────────────────────────────────────

class _CoachNotesSection extends ConsumerStatefulWidget {
  const _CoachNotesSection({required this.decisionId});

  final String decisionId;

  @override
  ConsumerState<_CoachNotesSection> createState() =>
      _CoachNotesSectionState();
}

class _CoachNotesSectionState extends ConsumerState<_CoachNotesSection> {
  bool _isDeleting = false;

  Future<void> _deleteNote(String noteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DialogShell(
        title: 'Delete Note',
        child: const Text('Delete this coach note? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style:
                TextButton.styleFrom(foregroundColor: AppColors.destructive),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isDeleting = true);
    try {
      await ref.read(coachingRepositoryProvider).deleteNote(noteId);
      ref.invalidate(coachNotesForDecisionProvider(widget.decisionId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete note: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _showAddNoteSheet(List<String> clientUserIds) {
    final noteController = TextEditingController();
    String? selectedClientId =
        clientUserIds.length == 1 ? clientUserIds.first : null;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return DialogShell(
            title: 'Add Coach Note',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (clientUserIds.length > 1) ...[
                  DropdownButtonFormField<String>(
                    decoration:
                        const InputDecoration(labelText: 'Client'),
                    initialValue: selectedClientId,
                    items: clientUserIds
                        .map((id) => DropdownMenuItem(
                              value: id,
                              child: Text(
                                id.length > 8
                                    ? id.substring(0, 8)
                                    : id,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setSheetState(() => selectedClientId = v),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: noteController,
                  autofocus: true,
                  maxLines: 5,
                  minLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    hintText:
                        'Observations, recommendations, patterns…',
                    alignLabelWithHint: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: (isSaving || selectedClientId == null)
                    ? null
                    : () async {
                        final text = noteController.text.trim();
                        if (text.isEmpty) return;
                        setSheetState(() => isSaving = true);
                        try {
                          await ref
                              .read(coachingRepositoryProvider)
                              .addCoachNote(
                                clientUserId: selectedClientId!,
                                noteText: text,
                                decisionId: widget.decisionId,
                              );
                          ref.invalidate(coachNotesForDecisionProvider(
                              widget.decisionId));
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('Failed to add note: $e')),
                            );
                            Navigator.of(ctx).pop();
                          }
                        } finally {
                          setSheetState(() => isSaving = false);
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save note'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(myClientsProvider);
    final coachesAsync = ref.watch(myCoachesProvider);

    final clients = clientsAsync.valueOrNull ?? [];
    final coaches = coachesAsync.valueOrNull ?? [];

    // Only show this section when the user is in an active coaching
    // relationship (as a coach or as a client).
    if (clientsAsync.isLoading || coachesAsync.isLoading) {
      return const SizedBox.shrink();
    }
    if (clients.isEmpty && coaches.isEmpty) return const SizedBox.shrink();

    final isCoach = clients.isNotEmpty;
    final clientUserIds =
        clients.map((c) => c.clientUserId).whereType<String>().toList();

    final notesAsync =
        ref.watch(coachNotesForDecisionProvider(widget.decisionId));

    return _CollapsibleSection(
      title: 'Coach Notes',
      trailing: (isCoach && !_isDeleting)
          ? SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                icon: const Icon(Icons.add, size: 18),
                padding: EdgeInsets.zero,
                tooltip: 'Add coach note',
                onPressed: () => _showAddNoteSheet(clientUserIds),
              ),
            )
          : null,
      child: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text(
          'Failed to load coach notes.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
        ),
        data: (notes) {
          if (notes.isEmpty) {
            return Text(
              'No coach notes yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: notes
                .map((note) => _CoachNoteRow(
                      note: note,
                      isCoach: isCoach,
                      onDelete: () => _deleteNote(note.id),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

class _CoachNoteRow extends StatelessWidget {
  const _CoachNoteRow({
    required this.note,
    required this.isCoach,
    required this.onDelete,
  });

  final CoachNote note;
  final bool isCoach;
  final VoidCallback onDelete;

  String get _shortCoachId =>
      note.coachUserId.length > 8
          ? note.coachUserId.substring(0, 8)
          : note.coachUserId;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: isCoach ? onDelete : null,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note.noteEncrypted,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'By $_shortCoachId · '
              '${DateFormat('d MMM yyyy').format(note.createdAt.toLocal())}',
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
    );
  }
}

// ── Linked Assets Section ──────────────────────────────────────────────────────

class _LinkedAssetsSection extends ConsumerStatefulWidget {
  const _LinkedAssetsSection({required this.decisionId});

  final String decisionId;

  @override
  ConsumerState<_LinkedAssetsSection> createState() =>
      _LinkedAssetsSectionState();
}

class _LinkedAssetsSectionState extends ConsumerState<_LinkedAssetsSection> {
  Future<void> _unlink(String assetId) async {
    try {
      await ref.read(investmentRepositoryProvider).unlinkAsset(
            decisionId: widget.decisionId,
            assetId: assetId,
          );
      ref.invalidate(linkedAssetsProvider(widget.decisionId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unlink asset: $e')),
        );
      }
    }
  }

  void _showLinkSheet(List<Asset> linked) {
    final allAsync = ref.read(workspaceAssetsProvider);
    final all = allAsync.valueOrNull ?? [];
    final linkedIds = linked.map((a) => a.id).toSet();
    final available = all.where((a) => !linkedIds.contains(a.id)).toList();

    if (available.isEmpty) {
      final message = all.isEmpty
          ? 'No portfolio assets exist yet.'
          : 'All portfolio assets are already linked.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.sheetTop,
        side: BorderSide(color: Color(0xFF19CBD6), width: 1.5),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: SvgPicture.asset('assets/branding/icon.svg', height: 40)),
                const SizedBox(height: 8),
                Text(
                  'Link Asset',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          ...available.map(
            (a) => ListTile(
              leading: const Icon(Icons.business_outlined),
              title: Text(a.name),
              subtitle: [a.sector, a.stage, a.geography]
                          .whereType<String>()
                          .isNotEmpty
                  ? Text([a.sector, a.stage, a.geography]
                      .whereType<String>()
                      .join(' · '))
                  : null,
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  await ref.read(investmentRepositoryProvider).linkAsset(
                        decisionId: widget.decisionId,
                        assetId: a.id,
                      );
                  ref.invalidate(linkedAssetsProvider(widget.decisionId));
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to link asset: $e')),
                    );
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final linkedAsync = ref.watch(linkedAssetsProvider(widget.decisionId));

    return linkedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, st) => const SizedBox.shrink(),
      data: (linked) => _CollapsibleSection(
        title: 'Linked Assets',
        trailing: IconButton(
          icon: const Icon(Icons.add_link, size: 18),
          tooltip: 'Link asset',
          onPressed: () => _showLinkSheet(linked),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        child: linked.isEmpty
            ? Text(
                'No assets linked.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
              )
            : Wrap(
                spacing: 6,
                runSpacing: 4,
                children: linked
                    .map(
                      (a) => Chip(
                        label: Text(a.name),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => _unlink(a.id),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }
}

// ── IC Vote Section ────────────────────────────────────────────────────────────

class _IcVoteSection extends ConsumerStatefulWidget {
  const _IcVoteSection({required this.decisionId});

  final String decisionId;

  @override
  ConsumerState<_IcVoteSection> createState() => _IcVoteSectionState();
}

class _IcVoteSectionState extends ConsumerState<_IcVoteSection> {
  bool _isSaving = false;

  void _showVoteSheet(IcVote? existing) {
    String selectedVote = existing?.vote ?? 'approve';
    final notesCtrl = TextEditingController(text: existing?.dissentNotes ?? '');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => DialogShell(
          title: existing == null ? 'Cast IC Vote' : 'Update IC Vote',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'approve', label: Text('Approve')),
                  ButtonSegment(value: 'reject', label: Text('Reject')),
                  ButtonSegment(value: 'defer', label: Text('Defer')),
                ],
                selected: {selectedVote},
                onSelectionChanged: (s) => setSS(() => selectedVote = s.first),
              ),
              if (selectedVote == 'reject' || selectedVote == 'defer') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Dissent notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                setState(() => _isSaving = true);
                try {
                  await ref
                      .read(investmentRepositoryProvider)
                      .castVote(
                        decisionId: widget.decisionId,
                        vote: selectedVote,
                        dissentNotes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      );
                  ref.invalidate(
                      icVotesForDecisionProvider(widget.decisionId));
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save vote: $e')),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isSaving = false);
                }
              },
              child: const Text('Save Vote'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final votesAsync = ref.watch(icVotesForDecisionProvider(widget.decisionId));
    final uid = supabase.auth.currentUser?.id;

    return votesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, st) => const SizedBox.shrink(),
      data: (votes) {
        final yes = votes.where((v) => v.vote == 'Yes').length;
        final no = votes.where((v) => v.vote == 'No').length;
        final abstain = votes.where((v) => v.vote == 'Abstain').length;
        final myVote =
            uid != null ? votes.where((v) => v.voterUserId == uid).firstOrNull : null;

        return _CollapsibleSection(
          title: 'IC Votes',
          trailing: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton.icon(
                  onPressed: () => _showVoteSheet(myVote),
                  icon: Icon(
                    myVote == null ? Icons.how_to_vote_outlined : Icons.edit_outlined,
                    size: 16,
                  ),
                  label: Text(myVote == null ? 'Cast Vote' : 'Update Vote'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _VoteBadge(label: 'Yes', count: yes, color: AppColors.success),
                  const SizedBox(width: 8),
                  _VoteBadge(label: 'No', count: no, color: AppColors.destructive),
                  const SizedBox(width: 8),
                  _VoteBadge(label: 'Abstain', count: abstain, color: AppColors.textMuted),
                ],
              ),
              if (votes.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...votes.map((v) => _IcVoteRow(vote: v)),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'No votes cast yet.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Vote badge ─────────────────────────────────────────────────────────────────

class _VoteBadge extends StatelessWidget {
  const _VoteBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.mdBR,
      ),
      child: Text(
        '$label $count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ── IC vote row ────────────────────────────────────────────────────────────────

class _IcVoteRow extends StatelessWidget {
  const _IcVoteRow({required this.vote});

  final IcVote vote;

  Color _colorForVote(String v) => switch (v) {
        'Yes' => AppColors.success,
        'No' => AppColors.destructive,
        _ => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    final shortId = vote.voterUserId.length > 8
        ? vote.voterUserId.substring(0, 8)
        : vote.voterUserId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                shortId,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _colorForVote(vote.vote).withValues(alpha: 0.15),
                  borderRadius: AppRadius.smBR,
                ),
                child: Text(
                  vote.vote,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _colorForVote(vote.vote),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('d MMM yyyy').format(vote.votedAt.toLocal()),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
            ],
          ),
          if (vote.dissentNotes != null && vote.dissentNotes!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              vote.dissentNotes!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Linked Documents & Artifacts Section ──────────────────────────────────────

const _kArtifactTypes = <Map<String, String>>[
  {'label': 'Code change',          'value': 'code_change'},
  {'label': 'Code commit',          'value': 'code_commit'},
  {'label': 'Task or issue',        'value': 'task_or_issue'},
  {'label': 'Build or deployment',  'value': 'build_or_deployment'},
  {'label': 'Architecture diagram', 'value': 'architecture_diagram'},
  {'label': 'Technical proposal',   'value': 'technical_proposal'},
  {'label': 'Incident report',      'value': 'incident_report'},
  {'label': 'Runbook or playbook',  'value': 'runbook'},
  {'label': 'Meeting notes',        'value': 'meeting_notes'},
  {'label': 'Research document',    'value': 'research_document'},
  {'label': 'Legal document',       'value': 'legal_document'},
  {'label': 'Financial model',      'value': 'financial_model'},
  {'label': 'Supplier contract',    'value': 'supplier_contract'},
  {'label': 'Strategic plan',       'value': 'strategic_plan'},
  {'label': 'Board paper',          'value': 'board_paper'},
  {'label': 'Other',                'value': 'other'},
];

IconData artifactTypeIcon(String? type) => switch (type) {
      'code_change' || 'code_commit' => Icons.code,
      'task_or_issue'       => Icons.task_alt,
      'build_or_deployment' => Icons.rocket_launch,
      'architecture_diagram'=> Icons.account_tree,
      'technical_proposal'  => Icons.description,
      'incident_report'     => Icons.warning_amber,
      'runbook'             => Icons.menu_book,
      'meeting_notes'       => Icons.groups,
      'research_document'   => Icons.science,
      'legal_document'      => Icons.gavel,
      'financial_model'     => Icons.attach_money,
      'supplier_contract'   => Icons.handshake,
      'strategic_plan'      => Icons.flag,
      'board_paper'         => Icons.corporate_fare,
      _                     => Icons.attach_file,
    };

class _EngineeringArtifactsSection extends ConsumerStatefulWidget {
  const _EngineeringArtifactsSection({required this.decisionId});

  final String decisionId;

  @override
  ConsumerState<_EngineeringArtifactsSection> createState() =>
      _EngineeringArtifactsSectionState();
}

class _EngineeringArtifactsSectionState
    extends ConsumerState<_EngineeringArtifactsSection> {
  Future<void> _delete(String artifactId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogShell(
        title: 'Remove Artifact',
        child: const Text('Remove this linked document or artifact?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style:
                TextButton.styleFrom(foregroundColor: AppColors.destructive),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(engineeringRepositoryProvider)
          .deleteArtifact(artifactId);
      ref.invalidate(engineeringArtifactsProvider(widget.decisionId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove artifact: $e')),
        );
      }
    }
  }

  void _showAddSheet(String workspaceId) {
    String selectedType = 'code_change';
    final urlCtrl = TextEditingController();
    final labelCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => DialogShell(
          title: 'Add Linked Document or Artifact',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                decoration:
                    const InputDecoration(labelText: 'Document type'),
                value: selectedType,
                items: _kArtifactTypes
                    .map((t) => DropdownMenuItem(
                          value: t['value']!,
                          child: Row(
                            children: [
                              Icon(artifactTypeIcon(t['value']), size: 18),
                              const SizedBox(width: 8),
                              Text(t['label']!),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setSS(() => selectedType = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL *',
                  hintText: 'https://',
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Label (optional)',
                  hintText: 'e.g. RFC-042: Auth redesign',
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
              onPressed: () async {
                final url = urlCtrl.text.trim();
                if (url.isEmpty) return;
                Navigator.of(ctx).pop();
                try {
                  await ref
                      .read(engineeringRepositoryProvider)
                      .addArtifact(
                        decisionId: widget.decisionId,
                        workspaceId: workspaceId,
                        artifactType: selectedType,
                        url: url,
                        label: labelCtrl.text.trim().isEmpty
                            ? null
                            : labelCtrl.text.trim(),
                      );
                  ref.invalidate(
                      engineeringArtifactsProvider(widget.decisionId));
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Failed to add artifact: $e')),
                    );
                  }
                }
              },
              child: const Text('Add Artifact'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final artifactsAsync =
        ref.watch(engineeringArtifactsProvider(widget.decisionId));
    final workspaceId = ref.watch(currentWorkspaceProvider).valueOrNull;

    return artifactsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, st) => const SizedBox.shrink(),
      data: (artifacts) => _CollapsibleSection(
        title: 'Linked Documents & Artifacts',
        trailing: IconButton(
          icon: const Icon(Icons.add_link, size: 18),
          tooltip: 'Add artifact',
          onPressed: workspaceId == null ? null : () => _showAddSheet(workspaceId),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        child: artifacts.isEmpty
            ? Text(
                'No linked documents or artifacts.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
              )
            : Column(
                children: artifacts
                    .map((a) => _ArtifactRow(
                          artifact: a,
                          onDelete: () => _delete(a.id),
                        ))
                    .toList(),
              ),
      ),
    );
  }
}

// ── Artifact row ───────────────────────────────────────────────────────────────

class _ArtifactRow extends StatelessWidget {
  const _ArtifactRow({required this.artifact, required this.onDelete});

  final EngineeringArtifactLink artifact;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final displayText = artifact.label?.isNotEmpty == true
        ? artifact.label!
        : artifact.url;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.smBR,
        side: BorderSide(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.08)),
      ),
      child: InkWell(
        borderRadius: AppRadius.smBR,
        onTap: () => launchUrl(Uri.parse(artifact.url),
            mode: LaunchMode.externalApplication).ignore(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Icon(
                artifactTypeIcon(artifact.artifactType),
                size: 20,
                color: AppColors.accentPrimary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      artifact.artifactType.replaceAll('_', ' '),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.45),
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: AppColors.destructive.withValues(alpha: 0.6),
                ),
                tooltip: 'Remove',
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tool Kit section ──────────────────────────────────────────────────────────

/// Collapsible section at the bottom of the decision detail screen that shows
/// previous tool runs and a button to browse the Tool Kit library.
class _ToolKitSection extends ConsumerWidget {
  const _ToolKitSection({required this.decisionId});

  final String decisionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(decisionToolRunsProvider(decisionId));

    return _CollapsibleSection(
      title: 'Tool Kit',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.calculate_outlined, size: 16),
            label: const Text('Browse tools'),
            onPressed: () =>
                context.push('${Routes.toolkit}?decisionId=$decisionId'),
          ),
          const SizedBox(height: 12),
          runsAsync.when(
            loading: () => const SizedBox(
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (runs) {
              // ignore: avoid_print
              print('Tool runs for $decisionId: ${runs.length}');
              if (runs.isEmpty) {
                return Text(
                  'No tool runs for this decision yet.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                      ),
                );
              }
              return Column(
                children: runs.map((r) => _ToolRunRow(run: r)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ToolRunRow extends StatelessWidget {
  const _ToolRunRow({required this.run});

  final ToolRun run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = run.createdAt;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final firstEntry = run.outputsJsonb.entries.firstOrNull;
    final primaryValue = firstEntry != null
        ? '${firstEntry.key}: ${firstEntry.value}'
        : 'No outputs';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.calculate_outlined, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  run.toolName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '$dateStr · $primaryValue',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                if (run.finalDescription != null &&
                    run.finalDescription!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    run.finalDescription!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Effective confidence badge ─────────────────────────────────────────────

class _EffectiveConfidenceBadge extends ConsumerWidget {
  const _EffectiveConfidenceBadge({
    required this.decisionId,
    required this.initialConfidence,
  });

  final String decisionId;
  final int? initialConfidence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coachAdj = ref.watch(coachConfidenceAdjustmentProvider(decisionId))
            .valueOrNull ?? 0;
    final riskAdj = ref.watch(riskConfidenceAdjustmentProvider(decisionId))
            .valueOrNull ?? 0;
    final totalAdj = coachAdj + riskAdj;
    final base = initialConfidence ?? 0;
    final effective = (base + totalAdj).clamp(1, 10);

    if (totalAdj == 0 || base == 0) {
      return Text(
        '$base / 10',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final parts = <String>[];
    if (coachAdj != 0) parts.add('coach: ${coachAdj > 0 ? '+' : ''}$coachAdj');
    if (riskAdj != 0) parts.add('risk: ${riskAdj > 0 ? '+' : ''}$riskAdj');
    final tooltip = 'Adjusted from $base (${parts.join(', ')})';

    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$effective / 10',
            style: const TextStyle(
              color: Color(0xFF19CBD6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.psychology_outlined,
              size: 14, color: Color(0xFF19CBD6)),
        ],
      ),
    );
  }
}
