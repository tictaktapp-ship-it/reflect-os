import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/widgets/workspace_switcher_chip.dart';
import 'package:reflect_os/features/coaching/data/models/coach_client_relationship.dart';
import 'package:reflect_os/features/coaching/data/models/coaching_session.dart';
import 'package:reflect_os/features/coaching/data/models/coaching_session_note.dart';
import 'package:reflect_os/features/coaching/providers/coaching_provider.dart';

class CoachDashboardScreen extends ConsumerWidget {
  const CoachDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(myClientsProvider);
    final coachesAsync = ref.watch(myCoachesProvider);

    return Scaffold(
      appBar: AppBar(title: const WorkspaceSwitcherChip()),
      body: ListView(
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

          Card(
            color: Theme.of(context).colorScheme.surface,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Coach notes are visible to both you and your client '
                      'on each decision.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── As a Coach ─────────────────────────────────────────────────
          _SectionHeader(
            title: 'My Clients',
            action: IconButton(
              icon: const Icon(Icons.person_add_outlined, size: 20),
              tooltip: 'Invite client',
              onPressed: () => _showInviteSheet(context, ref),
            ),
          ),
          clientsAsync.when(
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: 'Failed to load clients: $e'),
            data: (clients) => clients.isEmpty
                ? const _EmptyCard(
                    message: 'No active clients yet. '
                        'Invite someone to get started.')
                : Column(
                    children: clients
                        .map((c) => _ClientCard(
                              relationship: c,
                              onTap: () =>
                                  _showClientDetailSheet(context, ref, c),
                              onRevoke: () =>
                                  _confirmRevoke(context, ref, c),
                            ))
                        .toList(),
                  ),
          ),

          const SizedBox(height: 16),

          // ── As a Client ────────────────────────────────────────────────
          _SectionHeader(
            title: 'My Coaches',
            action: IconButton(
              icon: const Icon(Icons.person_add_outlined, size: 20),
              tooltip: 'Add coach',
              onPressed: () => _showAddCoachDialog(context, ref),
            ),
          ),
          coachesAsync.when(
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: 'Failed to load coaches: $e'),
            data: (coaches) => coaches.isEmpty
                ? const _EmptyCard(
                    message: 'No coaches have access to your decisions.')
                : Column(
                    children: coaches
                        .map((c) => _CoachCard(
                              relationship: c,
                              onViewNotes: () =>
                                  _showCoachNotesSheet(context, ref, c),
                              onRevoke: () =>
                                  _confirmRevoke(context, ref, c),
                            ))
                        .toList(),
                  ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showAddCoachDialog(BuildContext context, WidgetRef ref) {
    final emailController = TextEditingController();
    bool isBusy = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('Add a Coach'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter your coach\'s email address. '
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
                        final workspaceId = await ref
                            .read(currentWorkspaceProvider.future);
                        if (workspaceId == null) {
                          throw Exception('No active workspace');
                        }
                        await ref
                            .read(coachingRepositoryProvider)
                            .inviteCoach(email, workspaceId);
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          ref.invalidate(myCoachesProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Invite sent to $email')),
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

  void _showClientDetailSheet(
    BuildContext context,
    WidgetRef ref,
    CoachClientRelationship relationship,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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

  void _showCoachNotesSheet(
    BuildContext context,
    WidgetRef ref,
    CoachClientRelationship relationship,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollController) => _CoachNotesSheet(
          relationship: relationship,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showInviteSheet(BuildContext context, WidgetRef ref) {
    final emailController = TextEditingController();
    bool isBusy = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: SvgPicture.asset(
                        'assets/branding/icon.svg',
                        height: 128,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Invite Client',
                      style: Theme.of(sheetCtx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
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
                    const SizedBox(height: 16),
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
                                  ref.invalidate(myClientsProvider);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('Invite sent to $email')),
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
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmRevoke(
      BuildContext context, WidgetRef ref, CoachClientRelationship rel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Revoke Access'),
        content: const Text(
          'This will remove the coaching relationship. '
          'Existing notes will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: AppColors.destructive),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(coachingRepositoryProvider).revokeClient(rel.id);
      ref.invalidate(myClientsProvider);
      ref.invalidate(myCoachesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to revoke: $e')),
        );
      }
    }
  }
}

// ── Client detail bottom sheet ─────────────────────────────────────────────────

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
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _shortId {
    final id = widget.relationship.clientUserId;
    return id.length > 8 ? id.substring(0, 8) : id;
  }

  @override
  Widget build(BuildContext context) {
    final clientUserId = widget.relationship.clientUserId;
    final sessionsAsync = ref.watch(coachingSessionsProvider(clientUserId));
    final notesAsync =
        ref.watch(coachingSessionNotesProvider(clientUserId));

    return Column(
      children: [
        // Handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Client header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.accentPrimary,
                child: Text(
                  _shortId[0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _shortId,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Since ${DateFormat('d MMM yyyy').format(widget.relationship.grantedAt.toLocal())}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Session Notes'),
            Tab(text: 'Sessions'),
            Tab(text: 'Decision Notes'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Session Notes tab
              _SessionNotesTab(
                clientUserId: clientUserId,
                notesAsync: notesAsync,
                onAddNote: () => _showAddNoteDialog(context, clientUserId),
              ),
              // Sessions tab
              _SessionsTab(
                clientUserId: clientUserId,
                sessionsAsync: sessionsAsync,
                onSchedule: () =>
                    _showScheduleSessionDialog(context, clientUserId),
              ),
              // Decision Notes tab
              _DecisionNotesTab(
                onGoToDecisions: () => context.push(Routes.decisionsList),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddNoteDialog(BuildContext context, String clientUserId) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Add Session Note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Write your note here…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final body = controller.text.trim();
              if (body.isEmpty) return;
              Navigator.of(dialogCtx).pop();
              try {
                await ref
                    .read(coachingRepositoryProvider)
                    .addSessionNote(clientUserId: clientUserId, body: body);
                ref.invalidate(coachingSessionNotesProvider(clientUserId));
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add note: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showScheduleSessionDialog(
      BuildContext context, String clientUserId) {
    final titleController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    int durationMinutes = 60;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Schedule Session'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title (optional)'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    DateFormat('d MMM yyyy HH:mm').format(selectedDate)),
                subtitle: const Text('Date & time'),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          selectedDate.hour,
                          selectedDate.minute,
                        ));
                  }
                },
              ),
              DropdownButtonFormField<int>(
                initialValue: durationMinutes,
                decoration: const InputDecoration(labelText: 'Duration'),
                items: const [
                  DropdownMenuItem(value: 30, child: Text('30 min')),
                  DropdownMenuItem(value: 45, child: Text('45 min')),
                  DropdownMenuItem(value: 60, child: Text('60 min')),
                  DropdownMenuItem(value: 90, child: Text('90 min')),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => durationMinutes = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                try {
                  await ref.read(coachingRepositoryProvider).createSession(
                        clientUserId: clientUserId,
                        scheduledAt: selectedDate,
                        title: titleController.text.trim().isEmpty
                            ? null
                            : titleController.text.trim(),
                        durationMinutes: durationMinutes,
                      );
                  ref.invalidate(
                      coachingSessionsProvider(clientUserId));
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to schedule: $e')),
                    );
                  }
                }
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Session notes tab ──────────────────────────────────────────────────────────

class _SessionNotesTab extends StatelessWidget {
  const _SessionNotesTab({
    required this.clientUserId,
    required this.notesAsync,
    required this.onAddNote,
  });

  final String clientUserId;
  final AsyncValue<List<CoachingSessionNote>> notesAsync;
  final VoidCallback onAddNote;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: onAddNote,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Note'),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary),
              ),
            ],
          ),
        ),
        Expanded(
          child: notesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (notes) => notes.isEmpty
                ? const Center(child: Text('No session notes yet.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: notes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final note = notes[i];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.bodyEncrypted,
                                style:
                                    Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                DateFormat('d MMM yyyy')
                                    .format(note.createdAt.toLocal()),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.4),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Sessions tab ───────────────────────────────────────────────────────────────

class _SessionsTab extends StatelessWidget {
  const _SessionsTab({
    required this.clientUserId,
    required this.sessionsAsync,
    required this.onSchedule,
  });

  final String clientUserId;
  final AsyncValue<List<CoachingSession>> sessionsAsync;
  final VoidCallback onSchedule;

  Color _statusColor(CoachingSession s) {
    if (s.isOverdue) return const Color(0xFFDC4444);
    return switch (s.status) {
      'completed' => AppColors.success,
      'cancelled' => AppColors.textMuted,
      _ => AppColors.accentPrimary,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: onSchedule,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('Schedule Session'),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary),
              ),
            ],
          ),
        ),
        Expanded(
          child: sessionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (sessions) => sessions.isEmpty
                ? const Center(child: Text('No sessions yet.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: sessions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final s = sessions[i];
                      final statusColor = _statusColor(s);
                      final statusLabel =
                          s.isOverdue ? 'overdue' : s.status;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    if (s.title != null)
                                      Text(
                                        s.title!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    Text(
                                      DateFormat('d MMM yyyy HH:mm')
                                          .format(s.scheduledAt.toLocal()),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    Text(
                                      '${s.durationMinutes} min',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.5),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color:
                                      statusColor.withValues(alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: statusColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Decision notes tab ────────────────────────────────────────────────────────

class _DecisionNotesTab extends StatelessWidget {
  const _DecisionNotesTab({required this.onGoToDecisions});

  final VoidCallback onGoToDecisions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select a decision to add notes',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onGoToDecisions,
              icon: const Icon(Icons.task_alt_outlined),
              label: const Text('Go to Decisions'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Coach notes sheet (read-only for client) ───────────────────────────────────

class _CoachNotesSheet extends ConsumerWidget {
  const _CoachNotesSheet({
    required this.relationship,
    required this.scrollController,
  });

  final CoachClientRelationship relationship;
  final ScrollController scrollController;

  String get _shortId {
    final id = relationship.coachUserId;
    return id.length > 8 ? id.substring(0, 8) : id;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync =
        ref.watch(coachingSessionNotesProvider(relationship.clientUserId));

    return Column(
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.accentPrimary,
                child: Text(
                  _shortId[0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _shortId,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Coach · Since ${DateFormat('d MMM yyyy').format(relationship.grantedAt.toLocal())}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: notesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (notes) => notes.isEmpty
                ? const Center(child: Text('No notes from your coach yet.'))
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: notes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final note = notes[i];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.bodyEncrypted,
                                style:
                                    Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                DateFormat('d MMM yyyy')
                                    .format(note.createdAt.toLocal()),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.4),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

// ── Client card ────────────────────────────────────────────────────────────────

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.relationship,
    required this.onTap,
    required this.onRevoke,
  });

  final CoachClientRelationship relationship;
  final VoidCallback onTap;
  final VoidCallback onRevoke;

  String get _shortId =>
      relationship.clientUserId.length > 8
          ? relationship.clientUserId.substring(0, 8)
          : relationship.clientUserId;

  @override
  Widget build(BuildContext context) {
    final grantedStr =
        DateFormat('d MMM yyyy').format(relationship.grantedAt.toLocal());

    return GestureDetector(
      onLongPress: onRevoke,
      child: Card(
        clipBehavior: Clip.hardEdge,
        color: Theme.of(context).colorScheme.surface,
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.person_outlined, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _shortId,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      Text(
                        'Since $grantedStr',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Coach card ─────────────────────────────────────────────────────────────────

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.relationship,
    required this.onViewNotes,
    required this.onRevoke,
  });

  final CoachClientRelationship relationship;
  final VoidCallback onViewNotes;
  final VoidCallback onRevoke;

  String get _shortId =>
      relationship.coachUserId.length > 8
          ? relationship.coachUserId.substring(0, 8)
          : relationship.coachUserId;

  @override
  Widget build(BuildContext context) {
    final grantedStr =
        DateFormat('d MMM yyyy').format(relationship.grantedAt.toLocal());

    return Card(
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.psychology_outlined, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _shortId,
                    style:
                        Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                  ),
                  Text(
                    'Since $grantedStr',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onViewNotes,
              child: const Text('View Notes'),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.destructive,
                side: BorderSide(color: AppColors.destructive),
              ),
              onPressed: onRevoke,
              child: const Text('Revoke access'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared utility cards ───────────────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 10),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.destructive,
              ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
        ),
      ),
    );
  }
}
