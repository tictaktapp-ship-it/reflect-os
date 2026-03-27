import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/widgets/app_header.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/core/theme/app_radius.dart';
import 'package:reflect_os/features/coaching/data/models/coach_client_relationship.dart';
import 'package:reflect_os/features/coaching/data/models/coach_note.dart';
import 'package:reflect_os/features/coaching/data/models/coach_shared_decision.dart';
import 'package:reflect_os/features/coaching/data/models/coaching_action_item.dart';
import 'package:reflect_os/features/coaching/data/models/coaching_session.dart';
import 'package:reflect_os/features/coaching/data/models/coaching_session_note.dart';
import 'package:reflect_os/features/coaching/data/coaching_repository.dart';
import 'package:reflect_os/features/coaching/providers/coaching_provider.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reflect_os/widgets/dialog_shell.dart';

// ── Entry point ──────────────────────────────────────────────────────────────

class CoachDashboardScreen extends ConsumerStatefulWidget {
  const CoachDashboardScreen({super.key});

  @override
  ConsumerState<CoachDashboardScreen> createState() =>
      _CoachDashboardScreenState();
}

enum _ViewMode { coach, client }

class _CoachDashboardScreenState extends ConsumerState<CoachDashboardScreen> {
  _ViewMode _viewMode = _ViewMode.coach;
  CoachClientRelationship? _selectedClient;

  RealtimeChannel? _relChannel;
  RealtimeChannel? _sharedDecChannel;
  RealtimeChannel? _actionChannel;

  @override
  void initState() {
    super.initState();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _relChannel = supabase
        .channel('ccr_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'coach_client_relationships',
          callback: (_) {
            ref.invalidate(myClientsProvider);
            ref.invalidate(myCoachesProvider);
            ref.invalidate(myClientsAllProvider);
            ref.invalidate(myCoachesAllProvider);
            ref.invalidate(crossClientDashboardProvider);
          },
        )
        .subscribe();

    _sharedDecChannel = supabase
        .channel('csd_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'coach_shared_decisions',
          callback: (_) {
            ref.invalidate(clientSharedDecisionsProvider);
            ref.invalidate(crossClientDashboardProvider);
            if (_selectedClient?.clientUserId != null) {
              ref.invalidate(sharedDecisionsByClientProvider(
                  _selectedClient!.clientUserId!));
            }
          },
        )
        .subscribe();

    _actionChannel = supabase
        .channel('cai_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'coaching_action_items',
          callback: (_) {
            ref.invalidate(myActionItemsProvider);
            if (_selectedClient?.clientUserId != null) {
              ref.invalidate(actionItemsForClientProvider(
                  _selectedClient!.clientUserId!));
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _relChannel?.unsubscribe();
    _sharedDecChannel?.unsubscribe();
    _actionChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(myClientsProvider);
    final coachesAsync = ref.watch(myCoachesProvider);

    return Scaffold(
      appBar: const AppHeader(),
      body: clientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (clients) => coachesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (coaches) {
            final isCoach = clients.any((c) => c.isActive);
            final isClient = coaches.any((c) => c.isActive);

            if (!isCoach && !isClient) {
              return _NoCoachingView(
                onInviteClient: () => _showInviteClientDialog(context),
                onAddCoach: () => _showInviteCoachDialog(context),
              );
            }

            // Default view mode
            if (_viewMode == _ViewMode.client && !isClient) {
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => setState(() => _viewMode = _ViewMode.coach));
            }
            if (_viewMode == _ViewMode.coach && !isCoach) {
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => setState(() => _viewMode = _ViewMode.client));
            }

            return Column(
              children: [
                if (isCoach && isClient)
                  _RoleToggle(
                    mode: _viewMode,
                    onChanged: (m) => setState(() => _viewMode = m),
                  ),
                Expanded(
                  child: _viewMode == _ViewMode.coach
                      ? _CoachPortal(
                          clients: clients,
                          selectedClient: _selectedClient,
                          onSelectClient: (r) =>
                              setState(() => _selectedClient = r),
                          onInviteClient: () =>
                              _showInviteClientDialog(context),
                        )
                      : _ClientCoachingView(
                          coaches: coaches,
                          onAddCoach: () => _showInviteCoachDialog(context),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showInviteClientDialog(BuildContext context) {
    _InviteDialog.show(
      context: context,
      title: 'Invite Client',
      emailLabel: 'Client email',
      description:
          'Enter the email of the person you want to coach. '
          'They must already have a Reflect OS account.',
      onSubmit: (email) =>
          ref.read(coachingRepositoryProvider).inviteClient(email),
      onSuccess: () {
        ref.invalidate(myClientsProvider);
        ref.invalidate(myClientsAllProvider);
      },
    );
  }

  void _showInviteCoachDialog(BuildContext context) {
    _InviteDialog.show(
      context: context,
      title: 'Add Coach',
      emailLabel: 'Coach email',
      description:
          "Enter your coach's email address. "
          'They will be connected to your account.',
      onSubmit: (email) =>
          ref.read(coachingRepositoryProvider).inviteCoach(email),
      onSuccess: () {
        ref.invalidate(myCoachesProvider);
        ref.invalidate(myCoachesAllProvider);
      },
    );
  }
}

// ── Role toggle ───────────────────────────────────────────────────────────────

class _RoleToggle extends StatelessWidget {
  const _RoleToggle({required this.mode, required this.onChanged});
  final _ViewMode mode;
  final ValueChanged<_ViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SegmentedButton<_ViewMode>(
            segments: const [
              ButtonSegment(
                value: _ViewMode.coach,
                label: Text('Coach Portal'),
                icon: Icon(Icons.psychology_outlined, size: 16),
              ),
              ButtonSegment(
                value: _ViewMode.client,
                label: Text('My Coaching'),
                icon: Icon(Icons.school_outlined, size: 16),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (s) => onChanged(s.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

// ── No coaching relationships ─────────────────────────────────────────────────

class _NoCoachingView extends StatelessWidget {
  const _NoCoachingView(
      {required this.onInviteClient, required this.onAddCoach});
  final VoidCallback onInviteClient;
  final VoidCallback onAddCoach;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology_outlined,
                size: 56,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.25)),
            const SizedBox(height: 16),
            Text('Coaching',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Invite clients to coach, or add a coach to get guidance on your decisions.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: const Text('Invite a Client'),
                  onPressed: onInviteClient,
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.school_outlined, size: 16),
                  label: const Text('Add a Coach'),
                  onPressed: onAddCoach,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PART A — COACH PORTAL
// ════════════════════════════════════════════════════════════════════════════

class _CoachPortal extends StatelessWidget {
  const _CoachPortal({
    required this.clients,
    required this.selectedClient,
    required this.onSelectClient,
    required this.onInviteClient,
  });

  final List<CoachClientRelationship> clients;
  final CoachClientRelationship? selectedClient;
  final ValueChanged<CoachClientRelationship?> onSelectClient;
  final VoidCallback onInviteClient;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 800) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 240,
              child: _ClientListPanel(
                clients: clients,
                selectedClient: selectedClient,
                onSelectClient: onSelectClient,
                onInviteClient: onInviteClient,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: selectedClient != null
                  ? _ClientDetailPanel(
                      key: ValueKey(selectedClient!.id),
                      relationship: selectedClient!,
                      onBack: () => onSelectClient(null),
                    )
                  : _CrossClientDashboard(
                      onSelectClient: onSelectClient,
                    ),
            ),
          ],
        );
      }
      // Narrow: list only, tap opens detail sheet
      return _ClientListPanel(
        clients: clients,
        selectedClient: null,
        onSelectClient: (r) {
          if (r == null) return;
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.sheetTop,
              side: const BorderSide(color: Color(0xFF19CBD6), width: 1.5),
            ),
            builder: (_) => DraggableScrollableSheet(
              initialChildSize: 0.9,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (_, sc) => _ClientDetailPanel(
                relationship: r,
                onBack: () => Navigator.of(context).pop(),
                scrollController: sc,
              ),
            ),
          );
        },
        onInviteClient: onInviteClient,
      );
    });
  }
}

// ── Client list panel (left) ──────────────────────────────────────────────────

class _ClientListPanel extends StatelessWidget {
  const _ClientListPanel({
    required this.clients,
    required this.selectedClient,
    required this.onSelectClient,
    required this.onInviteClient,
  });

  final List<CoachClientRelationship> clients;
  final CoachClientRelationship? selectedClient;
  final ValueChanged<CoachClientRelationship?> onSelectClient;
  final VoidCallback onInviteClient;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
          child: Row(
            children: [
              Text(
                'MY CLIENTS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 1.1,
                    ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.person_add_outlined, size: 18),
                color: AppColors.accentPrimary,
                tooltip: 'Invite a client',
                onPressed: onInviteClient,
              ),
            ],
          ),
        ),
        if (clients.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: _EmptyCard(
              icon: Icons.supervised_user_circle_outlined,
              message: 'No clients yet',
              actionLabel: 'Invite a client',
              onAction: onInviteClient,
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 12),
              children: clients
                  .map((r) => _ClientTile(
                        relationship: r,
                        isSelected: selectedClient?.id == r.id,
                        onTap: () => onSelectClient(r),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _ClientTile extends ConsumerWidget {
  const _ClientTile({
    required this.relationship,
    required this.isSelected,
    required this.onTap,
  });

  final CoachClientRelationship relationship;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionItemsAsync = relationship.clientUserId != null
        ? ref.watch(
            actionItemsForClientProvider(relationship.clientUserId!))
        : null;

    int overdueItems = 0;
    actionItemsAsync?.whenData((items) {
      overdueItems = items.where((i) => i.isOverdue).length;
    });

    final sharedAsync = relationship.clientUserId != null
        ? ref.watch(
            sharedDecisionsByClientProvider(relationship.clientUserId!))
        : null;
    int sharedCount = 0;
    sharedAsync?.whenData((list) => sharedCount = list.length);

    final label = relationship.clientLabel;
    final initials = _initials(label);
    final bg = isSelected
        ? AppColors.accentPrimary.withValues(alpha: 0.07)
        : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: isSelected
              ? const Border(
                  left: BorderSide(color: AppColors.accentPrimary, width: 3))
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor:
                  AppColors.accentPrimary.withValues(alpha: 0.18),
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                  ),
                  Row(
                    children: [
                      if (overdueItems > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.2),
                            borderRadius: AppRadius.smBR,
                          ),
                          child: Text(
                            '$overdueItems overdue',
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (sharedCount > 0)
                        Text(
                          '$sharedCount decisions',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  fontSize: 10,
                                  color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ── Cross-client dashboard ────────────────────────────────────────────────────

class _CrossClientDashboard extends ConsumerWidget {
  const _CrossClientDashboard({required this.onSelectClient});
  final ValueChanged<CoachClientRelationship?> onSelectClient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(crossClientDashboardProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'Across All Clients'),
          const SizedBox(height: 12),
          dashAsync.when(
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: '$e'),
            data: (dash) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2×2 metric grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.4,
                  children: [
                    _MetricCard(
                        label: 'Total Active Decisions',
                        value: '${dash.totalActiveDecisions}'),
                    _MetricCard(
                        label: 'Overdue Reviews',
                        value: '${dash.overdueReviews}',
                        valueColor: dash.overdueReviews > 0
                            ? AppColors.destructive
                            : null),
                    _MetricCard(
                        label: 'Sessions This Month',
                        value: '${dash.sessionsThisMonth}'),
                    _MetricCard(
                        label: 'Active Clients',
                        value:
                            '${dash.attentionNeeded.map((a) => a.clientUserId).toSet().length}'),
                  ],
                ),
                if (dash.attentionNeeded.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionHeader(title: 'Attention Needed'),
                  const SizedBox(height: 8),
                  ...dash.attentionNeeded.map((item) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        child: ListTile(
                          dense: true,
                          leading: _HealthDot(healthState: item.healthState),
                          title: Text(
                            item.decisionTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodyMedium,
                          ),
                          subtitle: Text(item.clientName,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                          trailing: _HealthBadge(
                              healthState: item.healthState),
                        ),
                      )),
                ],
                if (dash.upcomingSessions.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionHeader(title: 'Upcoming Sessions'),
                  const SizedBox(height: 8),
                  ...dash.upcomingSessions.map((s) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: AppColors.accentPrimary),
                          title: Text(
                            s.title ??
                                DateFormat('d MMM yyyy').format(
                                    s.scheduledAt.toLocal()),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          subtitle: Text(
                            DateFormat('d MMM · HH:mm')
                                .format(s.scheduledAt.toLocal()),
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary),
                          ),
                        ),
                      )),
                ],
                if (dash.attentionNeeded.isEmpty &&
                    dash.upcomingSessions.isEmpty)
                  const _EmptyCard(
                    icon: Icons.check_circle_outline,
                    message: 'All clients are on track',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Client detail panel (right, 4 tabs) ───────────────────────────────────────

class _ClientDetailPanel extends ConsumerStatefulWidget {
  const _ClientDetailPanel({
    super.key,
    required this.relationship,
    required this.onBack,
    this.scrollController,
  });

  final CoachClientRelationship relationship;
  final VoidCallback onBack;
  final ScrollController? scrollController;

  @override
  ConsumerState<_ClientDetailPanel> createState() =>
      _ClientDetailPanelState();
}

class _ClientDetailPanelState extends ConsumerState<_ClientDetailPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rel = widget.relationship;
    final label = rel.clientLabel;
    final initials = _initials(label);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    AppColors.accentPrimary.withValues(alpha: 0.18),
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    if (rel.invitedEmail != null)
                      Text(rel.invitedEmail!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: AppColors.textSecondary)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule, size: 14),
                label: const Text('Schedule Session'),
                onPressed: rel.clientUserId != null
                    ? () => _showScheduleSession(context, rel.clientUserId!)
                    : null,
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.note_add, size: 14),
                label: const Text('Add Note'),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary),
                onPressed: rel.clientUserId != null
                    ? () => _showAddNoteSheet(context, rel.clientUserId!)
                    : null,
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Decisions'),
            Tab(text: 'Sessions'),
            Tab(text: 'Notes'),
            Tab(text: 'Action Items'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: rel.clientUserId != null
                ? [
                    _SharedDecisionsTab(
                        clientUserId: rel.clientUserId!,
                        relationship: rel),
                    _SessionsTab(relationship: rel),
                    _CoachNotesTab(clientUserId: rel.clientUserId!),
                    _ActionItemsTab(relationship: rel),
                  ]
                : List.generate(
                    4,
                    (_) => const Center(
                      child: Text(
                          'Client has not yet joined Reflect OS.',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _showScheduleSession(BuildContext context, String clientUserId) {
    _ScheduleSessionDialog.show(
      context: context,
      clientUserId: clientUserId,
      onSaved: () => ref.invalidate(
          coachingSessionsProvider(clientUserId)),
    );
  }

  void _showAddNoteSheet(BuildContext context, String clientUserId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.sheetTop,
        side: const BorderSide(color: Color(0xFF19CBD6), width: 1.5),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (_, sc) => _AddCoachNoteSheet(
          clientUserId: clientUserId,
          scrollController: sc,
          onSaved: () {
            ref.invalidate(coachNotesForClientProvider(clientUserId));
          },
        ),
      ),
    );
  }
}

// ── Tab 0: Shared Decisions ────────────────────────────────────────────────────

class _SharedDecisionsTab extends ConsumerWidget {
  const _SharedDecisionsTab({
    required this.clientUserId,
    required this.relationship,
  });
  final String clientUserId;
  final CoachClientRelationship relationship;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharedAsync =
        ref.watch(sharedDecisionsByClientProvider(clientUserId));

    return sharedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorCard(message: '$e'),
      data: (decisions) {
        if (decisions.isEmpty) {
          return const _EmptyCard(
            icon: Icons.gavel_outlined,
            message:
                'No decisions shared yet. Your client can share decisions from their Decisions screen.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: decisions.length,
          itemBuilder: (context, i) => _CoachSharedDecisionTile(
            shared: decisions[i],
            clientUserId: clientUserId,
          ),
        );
      },
    );
  }
}

class _CoachSharedDecisionTile extends ConsumerWidget {
  const _CoachSharedDecisionTile({
    required this.shared,
    required this.clientUserId,
  });
  final CoachSharedDecision shared;
  final String clientUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        borderRadius: AppRadius.mdBR,
        onTap: () => _showDetail(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _HealthDot(healthState: shared.decisionHealthState ?? ''),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shared.decisionTitle ?? 'Untitled',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    Row(
                      children: [
                        if (shared.decisionState != null)
                          _StateChip(state: shared.decisionState!),
                        if (shared.initialConfidence != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${shared.initialConfidence}/10',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 16, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.sheetTop,
        side: const BorderSide(color: Color(0xFF19CBD6), width: 1.5),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, sc) => _CoachDecisionDetailSheet(
          shared: shared,
          clientUserId: clientUserId,
          scrollController: sc,
        ),
      ),
    );
  }
}

class _CoachDecisionDetailSheet extends ConsumerStatefulWidget {
  const _CoachDecisionDetailSheet({
    required this.shared,
    required this.clientUserId,
    required this.scrollController,
  });
  final CoachSharedDecision shared;
  final String clientUserId;
  final ScrollController scrollController;

  @override
  ConsumerState<_CoachDecisionDetailSheet> createState() =>
      _CoachDecisionDetailSheetState();
}

class _CoachDecisionDetailSheetState
    extends ConsumerState<_CoachDecisionDetailSheet> {
  final _noteCtrl = TextEditingController();
  double _adjustment = 0;
  bool _sharedWithClient = false;
  bool _saving = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (_noteCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(coachingRepositoryProvider).addCoachNote(
            clientUserId: widget.clientUserId,
            noteText: _noteCtrl.text.trim(),
            decisionId: widget.shared.decisionId,
            confidenceAdjustment: _adjustment.round(),
            visibility:
                _sharedWithClient ? 'shared_with_client' : 'coach_only',
          );
      ref.invalidate(
          coachNotesForDecisionProvider(widget.shared.decisionId));
      ref.invalidate(coachNotesForClientProvider(widget.clientUserId));
      if (mounted) {
        _noteCtrl.clear();
        setState(() {
          _adjustment = 0;
          _sharedWithClient = false;
          _saving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(
        coachNotesForDecisionProvider(widget.shared.decisionId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.shared.decisionTitle ?? 'Decision',
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              // Decision overview
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Overview',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      if (widget.shared.decisionState != null)
                        _InfoRow(
                          label: 'State',
                          child: _StateChip(
                              state: widget.shared.decisionState!),
                        ),
                      if (widget.shared.stakes != null)
                        _InfoRow(
                          label: 'Stakes',
                          child: Text(widget.shared.stakes!,
                              style:
                                  Theme.of(context).textTheme.bodySmall),
                        ),
                      if (widget.shared.initialConfidence != null)
                        _InfoRow(
                          label: 'Confidence',
                          child: Text(
                              '${widget.shared.initialConfidence}/10',
                              style:
                                  Theme.of(context).textTheme.bodySmall),
                        ),
                      if (widget.shared.decisionHealthState != null)
                        _InfoRow(
                          label: 'Health',
                          child: _HealthBadge(
                              healthState:
                                  widget.shared.decisionHealthState!),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Coach notes on this decision
              Text('Coach Notes on This Decision',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              notesAsync.when(
                loading: () => const _LoadingCard(),
                error: (e, _) => _ErrorCard(message: '$e'),
                data: (notes) {
                  if (notes.isEmpty) {
                    return const _EmptyCard(
                        icon: Icons.notes_outlined,
                        message: 'No notes yet');
                  }
                  return Column(
                    children:
                        notes.map((n) => _CoachNoteCard(note: n)).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text('Add Note',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: _noteCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                    hintText: 'Your coaching note...'),
              ),
              const SizedBox(height: 12),
              Text(
                'Confidence: ${_adjustment.round() > 0 ? '+' : ''}${_adjustment.round()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Slider(
                value: _adjustment,
                min: -3,
                max: 3,
                divisions: 6,
                label: _sliderLabel(_adjustment.round()),
                onChanged: (v) => setState(() => _adjustment = v),
              ),
              Row(
                children: [
                  Switch(
                    value: _sharedWithClient,
                    onChanged: (v) =>
                        setState(() => _sharedWithClient = v),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _sharedWithClient
                        ? 'Share with client'
                        : 'Private (coach only)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary),
                onPressed: _saving ? null : _saveNote,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save note'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _sliderLabel(int v) {
    if (v <= -3) return 'Reduce significantly';
    if (v == 0) return 'No change';
    if (v >= 3) return 'Increase significantly';
    return '${v > 0 ? '+' : ''}$v';
  }
}

// ── Tab 1: Sessions ────────────────────────────────────────────────────────────

class _SessionsTab extends ConsumerStatefulWidget {
  const _SessionsTab({required this.relationship});
  final CoachClientRelationship relationship;

  @override
  ConsumerState<_SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends ConsumerState<_SessionsTab> {
  @override
  Widget build(BuildContext context) {
    final clientUserId = widget.relationship.clientUserId;
    if (clientUserId == null) {
      return const Center(
          child: Text('Client has not joined Reflect OS.',
              style: TextStyle(color: AppColors.textSecondary)));
    }

    final sessionsAsync = ref.watch(coachingSessionsProvider(clientUserId));
    final sessionNotesAsync =
        ref.watch(coachingSessionNotesProvider(clientUserId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Sessions',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Schedule'),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary),
                onPressed: () => _ScheduleSessionDialog.show(
                  context: context,
                  clientUserId: clientUserId,
                  onSaved: () => ref
                      .invalidate(coachingSessionsProvider(clientUserId)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          sessionsAsync.when(
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: '$e'),
            data: (sessions) {
              final now = DateTime.now();
              final upcoming = sessions
                  .where((s) =>
                      s.scheduledAt.isAfter(now) &&
                      s.status == 'scheduled')
                  .toList();
              final past = sessions
                  .where((s) =>
                      s.scheduledAt.isBefore(now) ||
                      s.status == 'completed')
                  .toList();

              if (sessions.isEmpty) {
                return const _EmptyCard(
                    icon: Icons.event_outlined,
                    message: 'No sessions yet');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (upcoming.isNotEmpty) ...[
                    Text('Upcoming',
                        style:
                            Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 6),
                    ...upcoming.map((s) => _SessionCard(
                          session: s,
                          isPast: false,
                          onStatusChange: (status) async {
                            await ref
                                .read(coachingRepositoryProvider)
                                .updateSessionStatus(s.id, status);
                            ref.invalidate(
                                coachingSessionsProvider(clientUserId));
                          },
                          onAddNote: null,
                        )),
                    const SizedBox(height: 16),
                  ],
                  if (past.isNotEmpty) ...[
                    Text('Past / Completed',
                        style:
                            Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 6),
                    ...past.map((s) => _SessionCard(
                          session: s,
                          isPast: true,
                          onStatusChange: (status) async {
                            await ref
                                .read(coachingRepositoryProvider)
                                .updateSessionStatus(s.id, status);
                            ref.invalidate(
                                coachingSessionsProvider(clientUserId));
                          },
                          onAddNote: () =>
                              _showAddSessionNote(context, s, clientUserId),
                        )),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Session Notes',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          sessionNotesAsync.when(
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: '$e'),
            data: (notes) {
              if (notes.isEmpty) {
                return const _EmptyCard(
                    icon: Icons.notes_outlined,
                    message: 'No session notes yet');
              }
              return Column(
                children: notes
                    .map((n) => Card(
                          margin:
                              const EdgeInsets.symmetric(vertical: 3),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(n.bodyEncrypted,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('d MMM yyyy')
                                      .format(n.createdAt.toLocal()),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color:
                                              AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddSessionNote(
      BuildContext context, CoachingSession session, String clientUserId) {
    final bodyCtrl = TextEditingController();
    bool isBusy = false;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setS) => DialogShell(
          title: 'Add Session Note',
          child: TextField(
            controller: bodyCtrl,
            maxLines: 5,
            autofocus: true,
            decoration:
                const InputDecoration(hintText: 'Session notes...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isBusy
                  ? null
                  : () async {
                      if (bodyCtrl.text.trim().isEmpty) return;
                      setS(() => isBusy = true);
                      try {
                        final workspaceId = await ref
                            .read(currentWorkspaceProvider.future);
                        await ref
                            .read(coachingRepositoryProvider)
                            .addSessionNoteForSession(
                              clientUserId: clientUserId,
                              body: bodyCtrl.text.trim(),
                              workspaceId: workspaceId,
                              coachingSessionId: session.id,
                            );
                        ref.invalidate(coachingSessionNotesProvider(
                            clientUserId));
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')));
                          Navigator.of(ctx).pop();
                        }
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 2: Notes (all coach notes for this client) ─────────────────────────────

class _CoachNotesTab extends ConsumerWidget {
  const _CoachNotesTab({required this.clientUserId});
  final String clientUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(coachNotesForClientProvider(clientUserId));

    return notesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorCard(message: '$e'),
      data: (notes) {
        if (notes.isEmpty) {
          return const _EmptyCard(
              icon: Icons.notes_outlined, message: 'No notes yet');
        }

        // Group: linked to a decision vs standalone
        final withDecision =
            notes.where((n) => n.decisionId != null).toList();
        final standalone =
            notes.where((n) => n.decisionId == null).toList();

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (withDecision.isNotEmpty) ...[
              Text('Linked to Decisions',
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              ...withDecision
                  .map((n) => _CoachNoteCard(note: n, showDecisionId: true)),
              const SizedBox(height: 16),
            ],
            if (standalone.isNotEmpty) ...[
              Text('Standalone',
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              ...standalone.map((n) => _CoachNoteCard(note: n)),
            ],
          ],
        );
      },
    );
  }
}

// ── Tab 3: Action Items ────────────────────────────────────────────────────────

class _ActionItemsTab extends ConsumerStatefulWidget {
  const _ActionItemsTab({required this.relationship});
  final CoachClientRelationship relationship;

  @override
  ConsumerState<_ActionItemsTab> createState() => _ActionItemsTabState();
}

class _ActionItemsTabState extends ConsumerState<_ActionItemsTab> {
  @override
  Widget build(BuildContext context) {
    final clientUserId = widget.relationship.clientUserId;
    if (clientUserId == null) {
      return const Center(
          child: Text('Client has not joined Reflect OS.',
              style: TextStyle(color: AppColors.textSecondary)));
    }

    final itemsAsync = ref.watch(actionItemsForClientProvider(clientUserId));

    return Scaffold(
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorCard(message: '$e'),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyCard(
                icon: Icons.check_circle_outline,
                message: 'No action items yet');
          }
          final pending = items.where((i) => !i.isCompleted).toList();
          final completed = items.where((i) => i.isCompleted).toList();
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (pending.isNotEmpty) ...[
                Text('Pending',
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 6),
                ...pending.map((item) => _ActionItemCard(
                      item: item,
                      onComplete: () async {
                        await ref
                            .read(coachingRepositoryProvider)
                            .markActionItemComplete(item.id);
                        ref.invalidate(
                            actionItemsForClientProvider(clientUserId));
                      },
                      onDelete: () async {
                        await ref
                            .read(coachingRepositoryProvider)
                            .deleteActionItem(item.id);
                        ref.invalidate(
                            actionItemsForClientProvider(clientUserId));
                      },
                    )),
                const SizedBox(height: 16),
              ],
              if (completed.isNotEmpty) ...[
                Text('Completed',
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 6),
                ...completed.map((item) => _ActionItemCard(
                      item: item,
                      onComplete: () {},
                      onDelete: () async {
                        await ref
                            .read(coachingRepositoryProvider)
                            .deleteActionItem(item.id);
                        ref.invalidate(
                            actionItemsForClientProvider(clientUserId));
                      },
                    )),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: AppColors.accentPrimary,
        onPressed: () => _showAddDialog(context, clientUserId),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context, String clientUserId) {
    final titleCtrl = TextEditingController();
    DateTime? dueDate;
    bool isBusy = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setD) => DialogShell(
          title: 'Add Action Item',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title *'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(dueDate != null
                    ? DateFormat('d MMM yyyy').format(dueDate!)
                    : 'Set due date (optional)'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate:
                        DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now()
                        .add(const Duration(days: 365)),
                  );
                  if (picked != null) setD(() => dueDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isBusy ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isBusy
                  ? null
                  : () async {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) return;
                      setD(() => isBusy = true);
                      try {
                        await ref
                            .read(coachingRepositoryProvider)
                            .createActionItem(
                              clientUserId: clientUserId,
                              title: title,
                              dueDate: dueDate,
                            );
                        ref.invalidate(
                            actionItemsForClientProvider(clientUserId));
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')));
                          Navigator.of(ctx).pop();
                        }
                      } finally {
                        setD(() => isBusy = false);
                      }
                    },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add coach note sheet ──────────────────────────────────────────────────────

class _AddCoachNoteSheet extends ConsumerStatefulWidget {
  const _AddCoachNoteSheet({
    required this.clientUserId,
    required this.scrollController,
    required this.onSaved,
  });
  final String clientUserId;
  final ScrollController scrollController;
  final VoidCallback onSaved;

  @override
  ConsumerState<_AddCoachNoteSheet> createState() =>
      _AddCoachNoteSheetState();
}

class _AddCoachNoteSheetState extends ConsumerState<_AddCoachNoteSheet> {
  final _noteCtrl = TextEditingController();
  double _adjustment = 0;
  String _visibility = 'coach_only';
  String? _linkedDecisionId;
  bool _saving = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_noteCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(coachingRepositoryProvider).addCoachNote(
            clientUserId: widget.clientUserId,
            noteText: _noteCtrl.text.trim(),
            decisionId: _linkedDecisionId,
            confidenceAdjustment: _adjustment.round(),
            visibility: _visibility,
          );
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sharedAsync = ref.watch(
        sharedDecisionsByClientProvider(widget.clientUserId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text('Add Coach Note',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              // Link to decision
              sharedAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (decisions) {
                  if (decisions.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Link to Decision (optional)',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 6),
                      InputDecorator(
                        decoration: const InputDecoration(),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _linkedDecisionId,
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem(
                                  value: null,
                                  child: Text('Standalone note')),
                              ...decisions.map(
                                (d) => DropdownMenuItem(
                                  value: d.decisionId,
                                  child: Text(
                                    d.decisionTitle ?? d.decisionId,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _linkedDecisionId = v),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),
              Text('Note',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              TextField(
                controller: _noteCtrl,
                maxLines: 5,
                autofocus: true,
                decoration:
                    const InputDecoration(hintText: 'Coaching note...'),
              ),
              const SizedBox(height: 12),
              Text(
                'Confidence adjustment: ${_adjustment.round() > 0 ? '+' : ''}${_adjustment.round()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Slider(
                value: _adjustment,
                min: -3,
                max: 3,
                divisions: 6,
                label: _sliderLabel(_adjustment.round()),
                onChanged: (v) => setState(() => _adjustment = v),
              ),
              Text('Visibility',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'coach_only',
                      label: Text('Private')),
                  ButtonSegment(
                      value: 'shared_with_client',
                      label: Text('Share with client')),
                ],
                selected: {_visibility},
                onSelectionChanged: (s) =>
                    setState(() => _visibility = s.first),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save note'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _sliderLabel(int v) {
    if (v <= -3) return 'Reduce significantly';
    if (v == 0) return 'No change';
    if (v >= 3) return 'Increase significantly';
    return '${v > 0 ? '+' : ''}$v';
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PART B — CLIENT COACHING VIEW
// ════════════════════════════════════════════════════════════════════════════

class _ClientCoachingView extends ConsumerWidget {
  const _ClientCoachingView({
    required this.coaches,
    required this.onAddCoach,
  });
  final List<CoachClientRelationship> coaches;
  final VoidCallback onAddCoach;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharedAsync = ref.watch(clientSharedDecisionsProvider);
    final notesAsync = ref.watch(notesSharedWithMeProvider);
    final itemsAsync = ref.watch(myActionItemsProvider);
    final sessionNotesAsync = ref.watch(mySessionNotesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── My Coaches ──────────────────────────────────────────────────
          Row(
            children: [
              _SectionHeader(title: 'My Coaches'),
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.person_add_outlined, size: 14),
                label: const Text('Add Coach'),
                onPressed: onAddCoach,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...coaches.map((r) => _CoachCard(
                relationship: r,
                onManage: () => _showManageCoach(context, ref, r),
              )),
          const SizedBox(height: 24),

          // ── Shared Decisions ─────────────────────────────────────────────
          Row(
            children: [
              _SectionHeader(title: 'Shared Decisions'),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.share_outlined, size: 14),
                label: const Text('Share a Decision'),
                onPressed: () =>
                    _showShareDecisionSheet(context, ref, coaches),
              ),
            ],
          ),
          Text(
            'These decisions are visible to your coach',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          sharedAsync.when(
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: '$e'),
            data: (shared) {
              if (shared.isEmpty) {
                return const _EmptyCard(
                  icon: Icons.gavel_outlined,
                  message: 'No decisions shared yet',
                );
              }
              return Column(
                children: shared
                    .map((s) => _SharedDecisionClientTile(
                          shared: s,
                          coachName: _coachName(coaches, s.coachUserId),
                          onRevoke: () async {
                            await ref
                                .read(coachingRepositoryProvider)
                                .revokeSharedDecision(s.id);
                            ref.invalidate(clientSharedDecisionsProvider);
                          },
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),

          // ── From Your Coach ──────────────────────────────────────────────
          _SectionHeader(title: 'From Your Coach'),
          const SizedBox(height: 8),
          notesAsync.when(
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: '$e'),
            data: (notes) {
              if (notes.isEmpty) {
                return const _EmptyCard(
                    icon: Icons.psychology_outlined,
                    message: 'No shared notes yet');
              }
              return Column(
                children: notes
                    .map((n) => _SharedNoteCard(
                          note: n,
                          coachName:
                              _coachName(coaches, n.coachUserId),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Action Items ─────────────────────────────────────────────────
          _SectionHeader(title: 'Action Items'),
          const SizedBox(height: 8),
          itemsAsync.when(
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: '$e'),
            data: (items) {
              final pending = items
                  .where((i) =>
                      !i.isCompleted)
                  .toList()
                ..sort((a, b) {
                  if (a.dueDate == null && b.dueDate == null) return 0;
                  if (a.dueDate == null) return 1;
                  if (b.dueDate == null) return -1;
                  return a.dueDate!.compareTo(b.dueDate!);
                });
              if (pending.isEmpty) {
                return const _EmptyCard(
                    icon: Icons.check_circle_outline,
                    message: 'No pending action items');
              }
              return Column(
                children: pending
                    .map((item) => _ClientActionItemTile(
                          item: item,
                          coachName:
                              _coachName(coaches, item.coachUserId),
                          onComplete: () async {
                            await ref
                                .read(coachingRepositoryProvider)
                                .markActionItemComplete(item.id);
                            ref.invalidate(myActionItemsProvider);
                          },
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Session Notes ────────────────────────────────────────────────
          _SectionHeader(title: 'Session Notes'),
          const SizedBox(height: 8),
          sessionNotesAsync.when(
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: '$e'),
            data: (notes) {
              if (notes.isEmpty) {
                return const _EmptyCard(
                    icon: Icons.notes_outlined,
                    message: 'No session notes yet');
              }
              return Column(
                children: notes
                    .map((n) => _SessionNotePreviewCard(note: n))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _coachName(List<CoachClientRelationship> coaches, String coachId) {
    try {
      return coaches
          .firstWhere((c) => c.coachUserId == coachId)
          .coachLabel;
    } catch (_) {
      return 'Coach';
    }
  }

  void _showManageCoach(
      BuildContext context, WidgetRef ref, CoachClientRelationship r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.sheetTop,
        side: const BorderSide(color: Color(0xFF19CBD6), width: 1.5),
      ),
      builder: (_) => _ManageCoachSheet(
        relationship: r,
        onRevoked: () {
          ref.invalidate(myCoachesProvider);
          ref.invalidate(myCoachesAllProvider);
        },
      ),
    );
  }

  void _showShareDecisionSheet(
    BuildContext context,
    WidgetRef ref,
    List<CoachClientRelationship> coaches,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.sheetTop,
        side: const BorderSide(color: Color(0xFF19CBD6), width: 1.5),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, sc) => _ShareDecisionSheet(
          coaches: coaches,
          scrollController: sc,
          onShared: () => ref.invalidate(clientSharedDecisionsProvider),
        ),
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.relationship, required this.onManage});
  final CoachClientRelationship relationship;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final label = relationship.coachLabel;
    final initials = _initials(label);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  AppColors.success.withValues(alpha: 0.18),
              child: Text(
                initials,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  if (relationship.invitedEmail != null)
                    Text(relationship.invitedEmail!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            TextButton(
              onPressed: onManage,
              child: const Text('Manage'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageCoachSheet extends ConsumerStatefulWidget {
  const _ManageCoachSheet(
      {required this.relationship, required this.onRevoked});
  final CoachClientRelationship relationship;
  final VoidCallback onRevoked;

  @override
  ConsumerState<_ManageCoachSheet> createState() => _ManageCoachSheetState();
}

class _ManageCoachSheetState extends ConsumerState<_ManageCoachSheet> {
  bool _revoking = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.relationship.coachLabel;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Manage Coach', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          if (widget.relationship.invitedEmail != null) ...[
            const SizedBox(height: 4),
            Text(widget.relationship.invitedEmail!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.link_off, size: 16),
            label: _revoking
                ? const Text('Revoking…')
                : const Text('Revoke Access'),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.destructive,
                side: const BorderSide(color: AppColors.destructive)),
            onPressed: _revoking
                ? null
                : () async {
                    setState(() => _revoking = true);
                    try {
                      await ref
                          .read(coachingRepositoryProvider)
                          .revokeClient(widget.relationship.id);
                      widget.onRevoked();
                      if (context.mounted) Navigator.of(context).pop();
                    } catch (e) {
                      if (context.mounted) {
                        setState(() => _revoking = false);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
          ),
        ],
      ),
    );
  }
}

class _SharedDecisionClientTile extends StatelessWidget {
  const _SharedDecisionClientTile({
    required this.shared,
    required this.coachName,
    required this.onRevoke,
  });
  final CoachSharedDecision shared;
  final String coachName;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _HealthDot(healthState: shared.decisionHealthState ?? ''),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shared.decisionTitle ?? 'Untitled',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Shared with $coachName',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.link_off, size: 16),
              color: AppColors.textMuted,
              tooltip: 'Stop sharing',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Stop Sharing?'),
                  content: Text(
                      'Your coach will no longer see "${shared.decisionTitle ?? 'this decision'}".'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onRevoke();
                        },
                        child: const Text('Stop Sharing')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedNoteCard extends StatelessWidget {
  const _SharedNoteCard(
      {required this.note, required this.coachName});
  final CoachNote note;
  final String coachName;

  @override
  Widget build(BuildContext context) {
    final adj = note.coachConfidenceAdjustment ?? 0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  coachName,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.accentPrimary),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('d MMM yyyy')
                      .format(note.createdAt.toLocal()),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(note.noteEncrypted,
                style: Theme.of(context).textTheme.bodySmall),
            if (adj != 0) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (adj > 0
                          ? AppColors.success
                          : AppColors.destructive)
                      .withValues(alpha: 0.12),
                  borderRadius: AppRadius.smBR,
                ),
                child: Text(
                  'Coach adjusted confidence ${adj > 0 ? '+' : ''}$adj',
                  style: TextStyle(
                    fontSize: 11,
                    color: adj > 0
                        ? AppColors.success
                        : AppColors.destructive,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClientActionItemTile extends StatelessWidget {
  const _ClientActionItemTile({
    required this.item,
    required this.coachName,
    required this.onComplete,
  });
  final CoachingActionItem item;
  final String coachName;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: Checkbox(
          value: item.isCompleted,
          onChanged: item.isCompleted ? null : (_) => onComplete(),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            decoration:
                item.isCompleted ? TextDecoration.lineThrough : null,
            color: item.isOverdue ? AppColors.destructive : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From $coachName',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            if (item.dueDate != null)
              Text(
                'Due: ${DateFormat('d MMM yyyy').format(item.dueDate!.toLocal())}',
                style: TextStyle(
                  fontSize: 11,
                  color: item.isOverdue
                      ? AppColors.destructive
                      : AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SessionNotePreviewCard extends StatelessWidget {
  const _SessionNotePreviewCard({required this.note});
  final CoachingSessionNote note;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: const Icon(Icons.notes_outlined,
            size: 18, color: AppColors.accentPrimary),
        title: Text(
          note.bodyEncrypted,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        subtitle: Text(
          DateFormat('d MMM yyyy').format(note.createdAt.toLocal()),
          style: const TextStyle(
              fontSize: 11, color: AppColors.textSecondary),
        ),
        trailing: TextButton(
          child: const Text('View'),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(DateFormat('d MMM yyyy')
                  .format(note.createdAt.toLocal())),
              content: SingleChildScrollView(
                child: Text(note.bodyEncrypted),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Share Decision Sheet ──────────────────────────────────────────────────────

class _ShareDecisionSheet extends ConsumerStatefulWidget {
  const _ShareDecisionSheet({
    required this.coaches,
    required this.scrollController,
    required this.onShared,
  });
  final List<CoachClientRelationship> coaches;
  final ScrollController scrollController;
  final VoidCallback onShared;

  @override
  ConsumerState<_ShareDecisionSheet> createState() =>
      _ShareDecisionSheetState();
}

class _ShareDecisionSheetState extends ConsumerState<_ShareDecisionSheet> {
  CoachClientRelationship? _selectedCoach;
  String _search = '';
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    final activeCoaches =
        widget.coaches.where((c) => c.isActive && c.coachUserId.isNotEmpty).toList();
    if (activeCoaches.length == 1) _selectedCoach = activeCoaches.first;
  }

  @override
  Widget build(BuildContext context) {
    final decisionsAsync = ref.watch(decisionsProvider);
    final sharedAsync = ref.watch(clientSharedDecisionsProvider);
    final activeCoaches = widget.coaches
        .where((c) => c.isActive)
        .toList();

    final alreadySharedIds = <String>{};
    sharedAsync.whenData((list) {
      if (_selectedCoach != null) {
        alreadySharedIds.addAll(list
            .where((s) => s.coachUserId == _selectedCoach!.coachUserId)
            .map((s) => s.decisionId));
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text('Share a Decision',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        if (activeCoaches.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InputDecorator(
              decoration:
                  const InputDecoration(labelText: 'Share with'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<CoachClientRelationship>(
                  value: _selectedCoach,
                  isExpanded: true,
                  hint: const Text('Select a coach'),
                  items: activeCoaches
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.coachLabel),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedCoach = v),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search decisions…',
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: decisionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorCard(message: '$e'),
            data: (decisions) {
              final filtered = decisions
                  .where((d) =>
                      d.state != 'Archived' &&
                      !alreadySharedIds.contains(d.id) &&
                      (_search.isEmpty ||
                          d.title
                              .toLowerCase()
                              .contains(_search.toLowerCase())))
                  .toList();

              if (filtered.isEmpty) {
                return const _EmptyCard(
                    icon: Icons.gavel_outlined,
                    message: 'No decisions to share');
              }
              return ListView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final d = filtered[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    child: ListTile(
                      title: Text(d.title,
                          style: Theme.of(context).textTheme.bodyMedium),
                      subtitle: Text(d.state,
                          style: const TextStyle(fontSize: 11)),
                      trailing: _sharing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor:
                                      AppColors.accentPrimary,
                                  visualDensity: VisualDensity.compact),
                              onPressed: _selectedCoach == null
                                  ? null
                                  : () => _share(d.id),
                              child: const Text('Share'),
                            ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _share(String decisionId) async {
    if (_selectedCoach == null) return;
    setState(() => _sharing = true);
    try {
      await ref.read(coachingRepositoryProvider).shareDecisionWithCoach(
            coachUserId: _selectedCoach!.coachUserId,
            decisionId: decisionId,
          );
      widget.onShared();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Decision shared')));
        setState(() => _sharing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sharing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PART C — DIALOGS
// ════════════════════════════════════════════════════════════════════════════

class _InviteDialog {
  static void show({
    required BuildContext context,
    required String title,
    required String emailLabel,
    required String description,
    required Future<void> Function(String email) onSubmit,
    required VoidCallback onSuccess,
  }) {
    final emailCtrl = TextEditingController();
    bool isBusy = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setS) => DialogShell(
          title: title,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(description,
                  style: Theme.of(ctx)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: emailLabel),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isBusy ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isBusy
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty) return;
                      setS(() => isBusy = true);
                      try {
                        await onSubmit(email);
                        onSuccess();
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Invite sent to $email')));
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')));
                        }
                      } finally {
                        setS(() => isBusy = false);
                      }
                    },
              child: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Send invite'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleSessionDialog {
  static void show({
    required BuildContext context,
    required String clientUserId,
    required VoidCallback onSaved,
  }) {
    final titleCtrl = TextEditingController();
    final resourceUrlCtrl = TextEditingController();
    final resourceLabelCtrl = TextEditingController();
    DateTime selectedDate =
        DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    int durationMinutes = 60;
    bool isBusy = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setS) => DialogShell(
          title: 'Schedule Session',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Title (optional)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 14),
                      label: Text(DateFormat('d MMM yyyy')
                          .format(selectedDate)),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365)),
                        );
                        if (d != null) setS(() => selectedDate = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 14),
                      label: Text(selectedTime.format(ctx)),
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: selectedTime,
                        );
                        if (t != null) setS(() => selectedTime = t);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Duration'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: durationMinutes,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 30, child: Text('30 min')),
                      DropdownMenuItem(value: 45, child: Text('45 min')),
                      DropdownMenuItem(value: 60, child: Text('60 min')),
                      DropdownMenuItem(value: 90, child: Text('90 min')),
                      DropdownMenuItem(
                          value: 120, child: Text('120 min')),
                    ],
                    onChanged: (v) {
                      if (v != null) setS(() => durationMinutes = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: resourceLabelCtrl,
                decoration: const InputDecoration(
                    labelText: 'Resource label (optional)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: resourceUrlCtrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                    labelText: 'Resource URL (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isBusy
                  ? null
                  : () async {
                      setS(() => isBusy = true);
                      try {
                        // Need ref — use a Consumer wrapper approach.
                        // We'll use the Supabase client directly via repository.
                        final scheduledAt = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );
                        await const CoachingRepository()
                            .createSessionFull(
                          clientUserId: clientUserId,
                          scheduledAt: scheduledAt,
                          title: titleCtrl.text.isNotEmpty
                              ? titleCtrl.text
                              : null,
                          durationMinutes: durationMinutes,
                          resourceUrl: resourceUrlCtrl.text,
                          resourceLabel: resourceLabelCtrl.text,
                        );
                        onSaved();
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('$e')));
                        }
                        setS(() => isBusy = false);
                      }
                    },
              child: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// UTILITY WIDGETS
// ════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 1.1,
              ),
        ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.isPast,
    required this.onAddNote,
    this.onStatusChange,
  });
  final CoachingSession session;
  final bool isPast;
  final VoidCallback? onAddNote;
  final ValueChanged<String>? onStatusChange;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title ??
                        DateFormat('d MMM yyyy, HH:mm')
                            .format(session.scheduledAt.toLocal()),
                    style:
                        Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: session.isOverdue
                                  ? AppColors.destructive
                                  : null,
                            ),
                  ),
                  Text(
                    '${DateFormat('d MMM yyyy · HH:mm').format(session.scheduledAt.toLocal())} · ${session.durationMinutes} min',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            _StatusBadge(status: session.status),
            if (isPast && onAddNote != null) ...[
              const SizedBox(width: 4),
              TextButton(
                  onPressed: onAddNote, child: const Text('Add notes')),
            ],
            if (onStatusChange != null)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                itemBuilder: (_) => [
                  if (session.status == 'scheduled') ...[
                    const PopupMenuItem(
                        value: 'completed',
                        child: Text('Mark completed')),
                    const PopupMenuItem(
                        value: 'cancelled',
                        child: Text('Cancel session')),
                  ],
                  if (session.status == 'cancelled')
                    const PopupMenuItem(
                        value: 'scheduled', child: Text('Reschedule')),
                ],
                onSelected: onStatusChange,
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionItemCard extends StatelessWidget {
  const _ActionItemCard({
    required this.item,
    required this.onComplete,
    required this.onDelete,
  });
  final CoachingActionItem item;
  final VoidCallback onComplete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: Checkbox(
          value: item.isCompleted,
          onChanged: item.isCompleted ? null : (_) => onComplete(),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            decoration:
                item.isCompleted ? TextDecoration.lineThrough : null,
            color: item.isOverdue ? AppColors.destructive : null,
          ),
        ),
        subtitle: item.dueDate != null
            ? Text(
                'Due: ${DateFormat('d MMM yyyy').format(item.dueDate!.toLocal())}',
                style: TextStyle(
                  fontSize: 11,
                  color: item.isOverdue
                      ? AppColors.destructive
                      : AppColors.textSecondary,
                ),
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          onPressed: onDelete,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _CoachNoteCard extends StatelessWidget {
  const _CoachNoteCard({required this.note, this.showDecisionId = false});
  final CoachNote note;
  final bool showDecisionId;

  @override
  Widget build(BuildContext context) {
    final adj = note.coachConfidenceAdjustment ?? 0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(note.noteEncrypted,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  DateFormat('d MMM yyyy').format(note.createdAt.toLocal()),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                if (adj != 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Adj: ${adj > 0 ? '+' : ''}$adj',
                    style: TextStyle(
                      fontSize: 11,
                      color: adj > 0
                          ? AppColors.success
                          : AppColors.destructive,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (note.visibility == 'shared_with_client') ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.visibility_outlined,
                      size: 12, color: AppColors.accentPrimary),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        color: AppColors.destructive.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(message,
              style: const TextStyle(
                  color: AppColors.destructive, fontSize: 12)),
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 36,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.25)),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 10),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final color = s == 'active' || s == 'scheduled'
        ? AppColors.success
        : s == 'completed'
            ? AppColors.accentPrimary
            : s == 'cancelled'
                ? AppColors.destructive
                : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.smBR,
      ),
      child: Text(
        status,
        style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state});
  final String state;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.08),
          borderRadius: AppRadius.smBR,
        ),
        child: Text(state,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontSize: 10)),
      );
}

class _HealthDot extends StatelessWidget {
  const _HealthDot({required this.healthState});
  final String healthState;

  @override
  Widget build(BuildContext context) {
    final color = switch (healthState) {
      'overdue' => AppColors.destructive,
      'needs_attention' => AppColors.warning,
      'on_track' => AppColors.success,
      _ => AppColors.textMuted,
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _HealthBadge extends StatelessWidget {
  const _HealthBadge({required this.healthState});
  final String healthState;

  @override
  Widget build(BuildContext context) {
    final color = switch (healthState) {
      'overdue' => AppColors.destructive,
      'needs_attention' => AppColors.warning,
      'on_track' => AppColors.success,
      _ => AppColors.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: AppRadius.smBR),
      child: Text(
        healthState.replaceAll('_', ' '),
        style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
            ),
            child,
          ],
        ),
      );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'[\s@.]+'));
  if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
}
