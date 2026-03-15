import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/widgets/app_header.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/coaching/data/models/coach_client_relationship.dart';
import 'package:reflect_os/features/coaching/data/models/coach_note.dart';
import 'package:reflect_os/features/coaching/data/models/coaching_action_item.dart';
import 'package:reflect_os/features/coaching/data/models/coaching_session.dart';
import 'package:reflect_os/features/coaching/providers/coaching_provider.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reflect_os/widgets/dialog_shell.dart';


class CoachDashboardScreen extends ConsumerStatefulWidget {
  const CoachDashboardScreen({super.key});

  @override
  ConsumerState<CoachDashboardScreen> createState() =>
      _CoachDashboardScreenState();
}

class _CoachDashboardScreenState extends ConsumerState<CoachDashboardScreen> {
  CoachClientRelationship? _selectedClient;
  RealtimeChannel? _relationshipChannel;
  RealtimeChannel? _actionItemChannel;

  @override
  void initState() {
    super.initState();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _relationshipChannel = supabase
        .channel('coach_client_relationships_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'coach_client_relationships',
          callback: (_) {
            ref.invalidate(myClientsAllProvider);
            ref.invalidate(myCoachesAllProvider);
          },
        )
        .subscribe();

    _actionItemChannel = supabase
        .channel('coaching_action_items_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'coaching_action_items',
          callback: (_) {
            ref.invalidate(actionItemsForClientProvider);
            ref.invalidate(myActionItemsProvider);
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _relationshipChannel?.unsubscribe();
    _actionItemChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return _buildWideLayout(context);
          }
          return _buildNarrowLayout(context);
        },
      ),
    );
  }

  // ── Wide layout ────────────────────────────────────────────────────────────

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left panel: client list
        SizedBox(
          width: 280,
          child: _buildClientListPanel(context),
        ),
        const VerticalDivider(width: 1),
        // Right panel: detail
        Expanded(
          child: _selectedClient != null
              ? _ClientDetailPanel(
                  key: ValueKey(_selectedClient!.id),
                  relationship: _selectedClient!,
                )
              : _buildSelectClientEmptyState(context),
        ),
      ],
    );
  }

  Widget _buildClientListPanel(BuildContext context) {
    final clientsAsync = ref.watch(myClientsAllProvider);
    final coachesAsync = ref.watch(myCoachesAllProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _SectionHeader(
                title: 'My Clients',
                trailing: IconButton(
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  tooltip: 'Invite a client',
                  onPressed: () => _showInviteSheet(context, ref),
                ),
              ),
              clientsAsync.when(
                loading: () => const _LoadingCard(),
                error: (e, _) => _ErrorCard(message: '$e'),
                data: (clients) => clients.isEmpty
                    ? _emptyCoachView(context)
                    : Column(
                        children: clients
                            .map((r) => _ClientListCard(
                                  relationship: r,
                                  isSelected: _selectedClient?.id == r.id,
                                  onTap: () => setState(
                                      () => _selectedClient = r),
                                ))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 16),
              _SectionHeader(
                title: 'My Coaches',
                trailing: IconButton(
                  icon: const Icon(Icons.group_add_outlined, size: 18),
                  tooltip: 'Add a coach',
                  onPressed: () => _showAddCoachDialog(context, ref),
                ),
              ),
              coachesAsync.when(
                loading: () => const _LoadingCard(),
                error: (e, _) => _ErrorCard(message: '$e'),
                data: (coaches) => coaches.isEmpty
                    ? _emptyClientView(context)
                    : Column(
                        children: coaches
                            .map((r) => _CoachListCard(
                                  relationship: r,
                                  onTap: () =>
                                      _showCoachDetailSheet(context, r),
                                ))
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: OutlinedButton.icon(
            onPressed: () => _showInviteSheet(context, ref),
            icon: const Icon(Icons.person_add_outlined, size: 16),
            label: const Text('Invite a client'),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectClientEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_search_outlined,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            'Select a client to view details',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  // ── Narrow layout ──────────────────────────────────────────────────────────

  Widget _buildNarrowLayout(BuildContext context) {
    final clientsAsync = ref.watch(myClientsAllProvider);
    final coachesAsync = ref.watch(myCoachesAllProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Work with your assigned coach to reflect on decisions and improve your decision-making over time.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
        ),
        _SectionHeader(
          title: 'My Clients',
          trailing: TextButton.icon(
            onPressed: () => _showInviteSheet(context, ref),
            icon: const Icon(Icons.person_add_outlined, size: 16),
            label: const Text('Invite'),
          ),
        ),
        const SizedBox(height: 8),
        clientsAsync.when(
          loading: () => const _LoadingCard(),
          error: (e, _) => _ErrorCard(message: '$e'),
          data: (clients) => clients.isEmpty
              ? _emptyCoachView(context)
              : Column(
                  children: clients
                      .map((r) => _ClientListCard(
                            relationship: r,
                            isSelected: false,
                            onTap: () => _showClientDetailSheet(context, r),
                          ))
                      .toList(),
                ),
        ),
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'My Coaches',
          trailing: TextButton.icon(
            onPressed: () => _showAddCoachDialog(context, ref),
            icon: const Icon(Icons.group_add_outlined, size: 16),
            label: const Text('Add'),
          ),
        ),
        const SizedBox(height: 8),
        coachesAsync.when(
          loading: () => const _LoadingCard(),
          error: (e, _) => _ErrorCard(message: '$e'),
          data: (coaches) => coaches.isEmpty
              ? _emptyClientView(context)
              : Column(
                  children: coaches
                      .map((r) => _CoachListCard(
                            relationship: r,
                            onTap: () => _showCoachDetailSheet(context, r),
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }

  // ── Empty states ───────────────────────────────────────────────────────────

  Widget _emptyCoachView(BuildContext context) {
    return _EmptyCard(
      icon: Icons.supervised_user_circle_outlined,
      message: 'No clients yet',
      actionLabel: 'Invite a client',
      onAction: () => _showInviteSheet(context, ref),
    );
  }

  Widget _emptyClientView(BuildContext context) {
    return _EmptyCard(
      icon: Icons.school_outlined,
      message: 'No coaches yet',
      actionLabel: 'Add a coach',
      onAction: () => _showAddCoachDialog(context, ref),
    );
  }

  // ── Dialogs / Sheets ───────────────────────────────────────────────────────

  void _showClientDetailSheet(
      BuildContext context, CoachClientRelationship relationship) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: Color(0xFF19CBD6), width: 1.5),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => _ClientDetailSheet(
          relationship: relationship,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showCoachDetailSheet(
      BuildContext context, CoachClientRelationship relationship) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: Color(0xFF19CBD6), width: 1.5),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => _CoachDetailSheet(
          relationship: relationship,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showAddCoachDialog(BuildContext context, WidgetRef ref) {
    final emailController = TextEditingController();
    bool isBusy = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => DialogShell(
          title: 'Add a Coach',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Enter your coach's email address. "
                'They will receive an invite to connect with you.',
                style: Theme.of(dialogCtx).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Coach email',
                  hintText: 'coach@example.com',
                ),
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
                      final email = emailController.text.trim();
                      if (email.isEmpty) return;
                      setDialogState(() => isBusy = true);
                      try {
                        final workspaceId =
                            await ref.read(currentWorkspaceProvider.future);
                        if (workspaceId == null) {
                          throw Exception('No active workspace');
                        }
                        await ref
                            .read(coachingRepositoryProvider)
                            .inviteCoach(email, workspaceId);
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          ref.invalidate(myCoachesAllProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Invite sent to $email')),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      } finally {
                        setDialogState(() => isBusy = false);
                      }
                    },
              child: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send invite'),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteSheet(BuildContext context, WidgetRef ref) {
    final emailController = TextEditingController();
    bool isBusy = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return DialogShell(
            title: 'Invite Client',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter the email address of the person you want to '
                  'coach. They must already have a Reflect OS account.',
                  style:
                      Theme.of(sheetCtx).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Client email',
                    hintText: 'name@example.com',
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
                onPressed: isBusy
                    ? null
                    : () async {
                        final email = emailController.text.trim();
                        if (email.isEmpty) return;
                        setSheetState(() => isBusy = true);
                        try {
                          final workspaceId = await ref
                              .read(currentWorkspaceProvider.future);
                          if (workspaceId == null) {
                            throw Exception('No active workspace');
                          }
                          await ref
                              .read(coachingRepositoryProvider)
                              .inviteClient(email, workspaceId);
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            ref.invalidate(myClientsAllProvider);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('Invite sent to $email')),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')),
                            );
                          }
                        } finally {
                          setSheetState(() => isBusy = false);
                        }
                      },
                child: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Invite'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Client list card ────────────────────────────────────────────────────────

class _ClientListCard extends ConsumerWidget {
  const _ClientListCard({
    required this.relationship,
    required this.isSelected,
    required this.onTap,
  });

  final CoachClientRelationship relationship;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync =
        ref.watch(coachingSessionsProvider(relationship.clientUserId));
    final actionItemsAsync =
        ref.watch(actionItemsForClientProvider(relationship.clientUserId));

    final displayName = relationship.invitedEmail ??
        'Client ${relationship.clientUserId.substring(0, 6)}';
    final initials = _initials(displayName);

    CoachingSession? nextSession;
    sessionsAsync.whenData((sessions) {
      final upcoming = sessions
          .where((s) =>
              s.scheduledAt.isAfter(DateTime.now()) &&
              s.status == 'scheduled')
          .toList();
      if (upcoming.isNotEmpty) {
        upcoming.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        nextSession = upcoming.first;
      }
    });

    int openActionItems = 0;
    actionItemsAsync.whenData((items) {
      openActionItems = items.where((i) => !i.isCompleted).length;
    });

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isSelected
          ? Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.3)
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.accentPrimary.withValues(alpha: 0.2),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppColors.accentPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _StatusBadge(status: relationship.status),
                        if (nextSession != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('d MMM').format(
                                nextSession!.scheduledAt.toLocal()),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                          ),
                        ],
                        if (openActionItems > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$openActionItems',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'[\s@.]+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }
}

// ── Coach list card ─────────────────────────────────────────────────────────

class _CoachListCard extends ConsumerWidget {
  const _CoachListCard({
    required this.relationship,
    required this.onTap,
  });

  final CoachClientRelationship relationship;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync =
        ref.watch(coachingSessionsProvider(relationship.clientUserId));
    final myItemsAsync = ref.watch(myActionItemsProvider);

    final displayName = relationship.invitedEmail ??
        'Coach ${relationship.coachUserId.substring(0, 6)}';
    final initials = _initials(displayName);

    CoachingSession? nextSession;
    sessionsAsync.whenData((sessions) {
      final upcoming = sessions
          .where((s) =>
              s.scheduledAt.isAfter(DateTime.now()) &&
              s.status == 'scheduled')
          .toList();
      if (upcoming.isNotEmpty) {
        upcoming.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        nextSession = upcoming.first;
      }
    });

    int openActionItems = 0;
    myItemsAsync.whenData((items) {
      openActionItems = items
          .where((i) =>
              !i.isCompleted &&
              i.coachUserId == relationship.coachUserId)
          .length;
    });

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    AppColors.success.withValues(alpha: 0.2),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _StatusBadge(status: relationship.status),
                        if (nextSession != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('d MMM').format(
                                nextSession!.scheduledAt.toLocal()),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                          ),
                        ],
                        if (openActionItems > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$openActionItems',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'[\s@.]+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }
}

// ── Client detail panel (wide layout) ──────────────────────────────────────

class _ClientDetailPanel extends ConsumerStatefulWidget {
  const _ClientDetailPanel({super.key, required this.relationship});

  final CoachClientRelationship relationship;

  @override
  ConsumerState<_ClientDetailPanel> createState() =>
      _ClientDetailPanelState();
}

class _ClientDetailPanelState extends ConsumerState<_ClientDetailPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Sessions'),
            Tab(text: 'Decision Notes'),
            Tab(text: 'Action Items'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _OverviewTab(relationship: widget.relationship),
              _SessionsTab(relationship: widget.relationship),
              _DecisionNotesTab(relationship: widget.relationship),
              _ActionItemsTab(relationship: widget.relationship),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Client detail sheet (narrow layout) ────────────────────────────────────

class _ClientDetailSheet extends ConsumerStatefulWidget {
  const _ClientDetailSheet({
    required this.relationship,
    required this.scrollController,
  });

  final CoachClientRelationship relationship;
  final ScrollController scrollController;

  @override
  ConsumerState<_ClientDetailSheet> createState() =>
      _ClientDetailSheetState();
}

class _ClientDetailSheetState extends ConsumerState<_ClientDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.relationship.invitedEmail ??
        'Client ${widget.relationship.clientUserId.substring(0, 6)}';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Text(displayName,
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              _StatusBadge(status: widget.relationship.status),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Sessions'),
            Tab(text: 'Notes'),
            Tab(text: 'Actions'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _OverviewTab(relationship: widget.relationship),
              _SessionsTab(relationship: widget.relationship),
              _DecisionNotesTab(relationship: widget.relationship),
              _ActionItemsTab(relationship: widget.relationship),
            ],
          ),
        ),
      ],
    );
  }
}

// ── TAB 1: Overview ─────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerStatefulWidget {
  const _OverviewTab({required this.relationship});
  final CoachClientRelationship relationship;

  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  late TextEditingController _focusController;
  late TextEditingController _goalsController;
  late TextEditingController _notesController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _focusController = TextEditingController(
        text: widget.relationship.focusAreasEncrypted ?? '');
    _goalsController =
        TextEditingController(text: widget.relationship.goalsEncrypted ?? '');
    _notesController =
        TextEditingController(text: widget.relationship.notesEncrypted ?? '');
  }

  @override
  void dispose() {
    _focusController.dispose();
    _goalsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(coachingRepositoryProvider).updateRelationshipFields(
            widget.relationship.id,
            focusAreas: _focusController.text,
            goals: _goalsController.text,
            notes: _notesController.text,
          );
      ref.invalidate(myClientsAllProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(
        coachNotesForClientProvider(widget.relationship.clientUserId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Relationship info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Relationship',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Status',
                    child: _StatusBadge(status: widget.relationship.status),
                  ),
                  _InfoRow(
                    label: 'Since',
                    child: Text(
                      DateFormat('d MMM yyyy').format(
                          widget.relationship.grantedAt.toLocal()),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (widget.relationship.invitedEmail != null)
                    _InfoRow(
                      label: 'Email',
                      child: Text(
                        widget.relationship.invitedEmail!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Focus Areas',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          TextField(
            controller: _focusController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'What areas is this client focusing on?',
            ),
          ),
          const SizedBox(height: 12),
          Text('Goals', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          TextField(
            controller: _goalsController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Key goals for this coaching relationship',
            ),
          ),
          const SizedBox(height: 12),
          Text('Internal Notes (Private)',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Private notes — not shared with client',
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save'),
            ),
          ),
          const SizedBox(height: 24),
          // Confidence impact table
          Text('Confidence Impact',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          notesAsync.when(
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: '$e'),
            data: (notes) {
              final byDecision = <String, List<CoachNote>>{};
              for (final note in notes) {
                if (note.decisionId != null) {
                  byDecision.putIfAbsent(note.decisionId!, () => []).add(note);
                }
              }
              if (byDecision.isEmpty) {
                return const _EmptyCard(
                  icon: Icons.psychology_outlined,
                  message: 'No confidence adjustments yet',
                );
              }
              return Column(
                children: byDecision.entries.map((entry) {
                  final sum = entry.value.fold<int>(
                      0,
                      (acc, n) =>
                          acc + (n.coachConfidenceAdjustment ?? 0));
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        entry.key.substring(0, 8),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: Text(
                        sum > 0 ? '+$sum' : '$sum',
                        style: TextStyle(
                          color: sum > 0
                              ? AppColors.success
                              : sum < 0
                                  ? AppColors.destructive
                                  : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── TAB 2: Sessions ─────────────────────────────────────────────────────────

class _SessionsTab extends ConsumerStatefulWidget {
  const _SessionsTab({required this.relationship});
  final CoachClientRelationship relationship;

  @override
  ConsumerState<_SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends ConsumerState<_SessionsTab> {
  Future<void> _showScheduleSheet(BuildContext context) async {
    final titleCtrl = TextEditingController();
    final resourceUrlCtrl = TextEditingController();
    final resourceLabelCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    int durationMinutes = 60;
    bool isBusy = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => DialogShell(
          title: 'Schedule Session',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
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
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                          DateFormat('d MMM yyyy').format(selectedDate)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: sheetCtx,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setSheet(() => selectedDate = picked);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text(selectedTime.format(sheetCtx)),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: sheetCtx,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setSheet(() => selectedTime = picked);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration:
                    const InputDecoration(labelText: 'Duration'),
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
                      if (v != null) setSheet(() => durationMinutes = v);
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
                decoration: const InputDecoration(
                    labelText: 'Resource URL (optional)'),
                keyboardType: TextInputType.url,
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
                      setSheet(() => isBusy = true);
                      try {
                        final scheduledAt = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );
                        final workspaceId = await ref.read(
                            currentWorkspaceProvider.future);
                        await ref
                            .read(coachingRepositoryProvider)
                            .createSessionFull(
                              clientUserId:
                                  widget.relationship.clientUserId,
                              scheduledAt: scheduledAt,
                              title: titleCtrl.text.isNotEmpty
                                  ? titleCtrl.text
                                  : null,
                              durationMinutes: durationMinutes,
                              workspaceId: workspaceId,
                              resourceUrl: resourceUrlCtrl.text,
                              resourceLabel: resourceLabelCtrl.text,
                            );
                        ref.invalidate(coachingSessionsProvider(
                            widget.relationship.clientUserId));
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      } finally {
                        setSheet(() => isBusy = false);
                      }
                    },
              child: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddNoteSheet(BuildContext context, CoachingSession session) {
    final bodyCtrl = TextEditingController();
    bool isBusy = false;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => DialogShell(
          title: 'Add Session Note',
          child: TextField(
            controller: bodyCtrl,
            maxLines: 5,
            autofocus: true,
            decoration: const InputDecoration(
                hintText: 'Session notes...'),
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
                      setSheet(() => isBusy = true);
                      try {
                        final workspaceId = await ref.read(
                            currentWorkspaceProvider.future);
                        await ref
                            .read(coachingRepositoryProvider)
                            .addSessionNoteForSession(
                              clientUserId:
                                  widget.relationship.clientUserId,
                              body: bodyCtrl.text.trim(),
                              workspaceId: workspaceId,
                              coachingSessionId: session.id,
                            );
                        ref.invalidate(coachingSessionNotesProvider(
                            widget.relationship.clientUserId));
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      } finally {
                        setSheet(() => isBusy = false);
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(
        coachingSessionsProvider(widget.relationship.clientUserId));
    final sessionNotesAsync = ref.watch(
        coachingSessionNotesProvider(widget.relationship.clientUserId));

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
                onPressed: () => _showScheduleSheet(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Schedule'),
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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (upcoming.isNotEmpty) ...[
                    Text('Upcoming',
                        style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 6),
                    ...upcoming.map((s) => _SessionCard(
                          session: s,
                          isPast: false,
                          onAddNote: null,
                        )),
                    const SizedBox(height: 16),
                  ],
                  if (past.isNotEmpty) ...[
                    Text('Past / Completed',
                        style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 6),
                    ...past.map((s) => _SessionCard(
                          session: s,
                          isPast: true,
                          onAddNote: () =>
                              _showAddNoteSheet(context, s),
                        )),
                  ],
                  if (sessions.isEmpty)
                    const _EmptyCard(
                      icon: Icons.event_outlined,
                      message: 'No sessions yet',
                    ),
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
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n.bodyEncrypted,
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('d MMM yyyy').format(
                                      n.createdAt.toLocal()),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: AppColors.textSecondary),
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
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.isPast,
    required this.onAddNote,
  });

  final CoachingSession session;
  final bool isPast;
  final VoidCallback? onAddNote;

  @override
  Widget build(BuildContext context) {
    final isOverdue = session.isOverdue;
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isOverdue
                              ? const Color(0xFFDC4444)
                              : null,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  Text(
                    '${DateFormat('d MMM yyyy · HH:mm').format(session.scheduledAt.toLocal())} · ${session.durationMinutes} min',
                    style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                  ),
                ],
              ),
            ),
            if (isPast && onAddNote != null)
              TextButton(
                onPressed: onAddNote,
                child: const Text('Add notes'),
              ),
          ],
        ),
      ),
    );
  }
}

// ── TAB 3: Decision Notes ────────────────────────────────────────────────────

class _DecisionNotesTab extends ConsumerWidget {
  const _DecisionNotesTab({required this.relationship});
  final CoachClientRelationship relationship;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decisionsAsync = ref.watch(decisionsProvider);

    return decisionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorCard(message: '$e'),
      data: (decisions) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Showing decisions from your current workspace.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          Expanded(
            child: decisions.isEmpty
                ? const _EmptyCard(
                    icon: Icons.gavel_outlined,
                    message: 'No decisions in current workspace',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: decisions.length,
                    itemBuilder: (context, index) {
                      final decision = decisions[index];
                      return _DecisionNoteCard(
                        decision: decision,
                        clientUserId: relationship.clientUserId,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DecisionNoteCard extends ConsumerWidget {
  const _DecisionNoteCard({
    required this.decision,
    required this.clientUserId,
  });

  final Decision decision;
  final String clientUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adjustmentAsync =
        ref.watch(coachConfidenceAdjustmentProvider(decision.id));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showNotesSheet(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      decision.title,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _StateChip(state: decision.state),
                        if (decision.initialConfidence != null) ...[
                          const SizedBox(width: 8),
                          adjustmentAsync.when(
                            loading: () => Text(
                                '${decision.initialConfidence} / 10',
                                style:
                                    Theme.of(context).textTheme.bodySmall),
                            error: (e, st) => Text(
                                '${decision.initialConfidence} / 10',
                                style:
                                    Theme.of(context).textTheme.bodySmall),
                            data: (adj) {
                              final base =
                                  decision.initialConfidence ?? 0;
                              final effective =
                                  (base + adj).clamp(1, 10);
                              if (adj == 0) {
                                return Text('$base / 10',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall);
                              }
                              final sign = adj > 0 ? '+' : '';
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('$effective / 10',
                                      style: const TextStyle(
                                        color: Color(0xFF19CBD6),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      )),
                                  const SizedBox(width: 2),
                                  Text(
                                    '($sign$adj)',
                                    style: const TextStyle(
                                      color: Color(0xFF19CBD6),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              );
                            },
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

  void _showNotesSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: Color(0xFF19CBD6), width: 1.5),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => _DecisionNotesSheet(
          decision: decision,
          clientUserId: clientUserId,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _DecisionNotesSheet extends ConsumerStatefulWidget {
  const _DecisionNotesSheet({
    required this.decision,
    required this.clientUserId,
    required this.scrollController,
  });

  final Decision decision;
  final String clientUserId;
  final ScrollController scrollController;

  @override
  ConsumerState<_DecisionNotesSheet> createState() =>
      _DecisionNotesSheetState();
}

class _DecisionNotesSheetState extends ConsumerState<_DecisionNotesSheet> {
  final _noteCtrl = TextEditingController();
  double _adjustment = 0;
  bool _sharedWithClient = false;
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
            decisionId: widget.decision.id,
            confidenceAdjustment: _adjustment.round(),
            visibility:
                _sharedWithClient ? 'shared_with_client' : 'coach_only',
          );
      ref.invalidate(
          coachNotesForDecisionProvider(widget.decision.id));
      ref.invalidate(
          coachNotesForClientProvider(widget.clientUserId));
      ref.invalidate(
          coachConfidenceAdjustmentProvider(widget.decision.id));
      if (mounted) {
        _noteCtrl.clear();
        setState(() {
          _adjustment = 0;
          _sharedWithClient = false;
          _saving = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Note saved')));
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
        coachNotesForDecisionProvider(widget.decision.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.decision.title,
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
              notesAsync.when(
                loading: () => const _LoadingCard(),
                error: (e, _) => _ErrorCard(message: '$e'),
                data: (notes) {
                  if (notes.isEmpty) {
                    return const _EmptyCard(
                      icon: Icons.notes_outlined,
                      message: 'No notes yet',
                    );
                  }
                  return Column(
                    children: notes
                        .map((n) => _CoachNoteCard(note: n))
                        .toList(),
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
                'Confidence adjustment: ${_adjustment.round() > 0 ? '+' : ''}${_adjustment.round()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Slider(
                value: _adjustment,
                min: -3,
                max: 3,
                divisions: 6,
                label: _adjustment.round().toString(),
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
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save note'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CoachNoteCard extends StatelessWidget {
  const _CoachNoteCard({required this.note});
  final CoachNote note;

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
                      color:
                          adj > 0 ? AppColors.success : AppColors.destructive,
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

// ── TAB 4: Action Items ─────────────────────────────────────────────────────

class _ActionItemsTab extends ConsumerStatefulWidget {
  const _ActionItemsTab({required this.relationship});
  final CoachClientRelationship relationship;

  @override
  ConsumerState<_ActionItemsTab> createState() => _ActionItemsTabState();
}

class _ActionItemsTabState extends ConsumerState<_ActionItemsTab> {
  void _showAddDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    DateTime? dueDate;
    bool isBusy = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialog) => DialogShell(
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
                    context: dialogCtx,
                    initialDate:
                        DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setDialog(() => dueDate = picked);
                  }
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
                      setDialog(() => isBusy = true);
                      try {
                        await ref
                            .read(coachingRepositoryProvider)
                            .createActionItem(
                              clientUserId:
                                  widget.relationship.clientUserId,
                              title: title,
                              dueDate: dueDate,
                            );
                        ref.invalidate(actionItemsForClientProvider(
                            widget.relationship.clientUserId));
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')));
                          Navigator.of(ctx).pop();
                        }
                      } finally {
                        setDialog(() => isBusy = false);
                      }
                    },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(
        actionItemsForClientProvider(widget.relationship.clientUserId));

    return Scaffold(
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorCard(message: '$e'),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyCard(
              icon: Icons.check_circle_outline,
              message: 'No action items yet',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _ActionItemCard(
                item: item,
                onComplete: () async {
                  await ref
                      .read(coachingRepositoryProvider)
                      .markActionItemComplete(item.id);
                  ref.invalidate(actionItemsForClientProvider(
                      widget.relationship.clientUserId));
                },
                onDelete: () async {
                  await ref
                      .read(coachingRepositoryProvider)
                      .deleteActionItem(item.id);
                  ref.invalidate(actionItemsForClientProvider(
                      widget.relationship.clientUserId));
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
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
            color: item.isOverdue ? const Color(0xFFDC4444) : null,
          ),
        ),
        subtitle: item.dueDate != null
            ? Text(
                'Due: ${DateFormat('d MMM yyyy').format(item.dueDate!.toLocal())}',
                style: TextStyle(
                  color: item.isOverdue
                      ? const Color(0xFFDC4444)
                      : AppColors.textSecondary,
                  fontSize: 11,
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

// ── Coach detail sheet ──────────────────────────────────────────────────────

class _CoachDetailSheet extends ConsumerStatefulWidget {
  const _CoachDetailSheet({
    required this.relationship,
    required this.scrollController,
  });

  final CoachClientRelationship relationship;
  final ScrollController scrollController;

  @override
  ConsumerState<_CoachDetailSheet> createState() =>
      _CoachDetailSheetState();
}

class _CoachDetailSheetState extends ConsumerState<_CoachDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.relationship.invitedEmail ??
        'Coach ${widget.relationship.coachUserId.substring(0, 6)}';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Text(displayName,
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              _StatusBadge(status: widget.relationship.status),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Sessions'),
            Tab(text: 'Action Items'),
            Tab(text: 'Insights'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _CoachSessionsTab(
                relationship: widget.relationship,
                scrollController: widget.scrollController,
              ),
              _ClientActionItemsTab(
                relationship: widget.relationship,
              ),
              _InsightsTab(relationship: widget.relationship),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Coach sessions tab (client view — read-only) ─────────────────────────────

class _CoachSessionsTab extends ConsumerWidget {
  const _CoachSessionsTab({
    required this.relationship,
    required this.scrollController,
  });

  final CoachClientRelationship relationship;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(
        coachingSessionsProvider(relationship.clientUserId));
    final sessionNotesAsync = ref.watch(
        coachingSessionNotesProvider(relationship.clientUserId));

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        sessionsAsync.when(
          loading: () => const _LoadingCard(),
          error: (e, _) => _ErrorCard(message: '$e'),
          data: (sessions) {
            if (sessions.isEmpty) {
              return const _EmptyCard(
                  icon: Icons.event_outlined,
                  message: 'No sessions scheduled');
            }
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (upcoming.isNotEmpty) ...[
                  Text('Upcoming',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  ...upcoming.map((s) => _SessionCard(
                        session: s,
                        isPast: false,
                        onAddNote: null,
                      )),
                  const SizedBox(height: 16),
                ],
                if (past.isNotEmpty) ...[
                  Text('Past',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  ...past.map((s) =>
                      _SessionCard(session: s, isPast: true, onAddNote: null)),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 16),
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
                  message: 'No session notes');
            }
            return Column(
              children: notes
                  .map((n) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.bodyEncrypted,
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('d MMM yyyy')
                                    .format(n.createdAt.toLocal()),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: AppColors.textSecondary),
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
    );
  }
}

// ── Client action items tab (client's own items from a coach) ────────────────

class _ClientActionItemsTab extends ConsumerWidget {
  const _ClientActionItemsTab({required this.relationship});
  final CoachClientRelationship relationship;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(myActionItemsProvider);

    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorCard(message: '$e'),
      data: (allItems) {
        final items = allItems
            .where((i) => i.coachUserId == relationship.coachUserId)
            .toList();
        if (items.isEmpty) {
          return const _EmptyCard(
              icon: Icons.check_circle_outline,
              message: 'No action items from this coach');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _ActionItemCard(
              item: item,
              onComplete: () async {
                await ref
                    .read(coachingRepositoryProvider)
                    .markActionItemComplete(item.id);
                ref.invalidate(myActionItemsProvider);
              },
              onDelete: () async {
                await ref
                    .read(coachingRepositoryProvider)
                    .deleteActionItem(item.id);
                ref.invalidate(myActionItemsProvider);
              },
            );
          },
        );
      },
    );
  }
}

// ── Insights tab ─────────────────────────────────────────────────────────────

class _InsightsTab extends ConsumerWidget {
  const _InsightsTab({required this.relationship});
  final CoachClientRelationship relationship;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(
        coachNotesForClientProvider(relationship.clientUserId));

    return notesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorCard(message: '$e'),
      data: (allNotes) {
        final sharedNotes = allNotes
            .where((n) =>
                n.visibility == 'shared_with_client' &&
                n.coachUserId == relationship.coachUserId)
            .toList();
        if (sharedNotes.isEmpty) {
          return const _EmptyCard(
            icon: Icons.psychology_outlined,
            message: 'No shared insights yet',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: sharedNotes.length,
          itemBuilder: (context, index) =>
              _CoachNoteCard(note: sharedNotes[index]),
        );
      },
    );
  }
}

// ── Utility widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

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
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.destructive.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: const TextStyle(color: AppColors.destructive, fontSize: 12),
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return Padding(
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
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final isPending = status.toLowerCase() == 'pending';
    final isActive = status.toLowerCase() == 'active';
    final color = isPending
        ? const Color(0xFFD97D24)
        : isActive
            ? AppColors.success
            : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state});
  final String state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .onSurface
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        state,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
