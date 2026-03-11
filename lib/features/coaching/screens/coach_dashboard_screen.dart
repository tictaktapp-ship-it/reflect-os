import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/widgets/workspace_switcher_chip.dart';
import 'package:reflect_os/features/coaching/data/models/coach_client_relationship.dart';
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
          // ── Screen description ─────────────────────────────────────
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

          // ── Visibility note ────────────────────────────────────────
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

          // ── My Clients ─────────────────────────────────────────────
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
                ? const _EmptyCard(message: 'No active clients yet. '
                    'Invite someone to get started.')
                : Column(
                    children: clients
                        .map((c) => _ClientCard(
                              relationship: c,
                              onViewDecisions: () =>
                                  context.push(Routes.decisionsList),
                              onRevoke: () =>
                                  _confirmRevoke(context, ref, c),
                            ))
                        .toList(),
                  ),
          ),

          const SizedBox(height: 16),

          // ── My Coaches ─────────────────────────────────────────────
          const _SectionHeader(title: 'My Coaches'),
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
                        Theme.of(sheetCtx).brightness == Brightness.dark
                            ? 'assets/branding/icon.svg'
                            : 'assets/branding/icon.svg',
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
                      style: Theme.of(sheetCtx).textTheme.bodySmall?.copyWith(
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
                                await ref
                                    .read(coachingRepositoryProvider)
                                    .inviteClient(email);
                                if (ctx.mounted) {
                                  Navigator.of(ctx).pop();
                                  ref.invalidate(myClientsProvider);
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
            style:
                TextButton.styleFrom(foregroundColor: AppColors.destructive),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(coachingRepositoryProvider)
          .revokeClient(rel.id);
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

// ── Section header ──────────────────────────────────────────────────────────────

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

// ── Client card ─────────────────────────────────────────────────────────────────

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.relationship,
    required this.onViewDecisions,
    required this.onRevoke,
  });

  final CoachClientRelationship relationship;
  final VoidCallback onViewDecisions;
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
        color: Theme.of(context).colorScheme.surface,
        margin: const EdgeInsets.only(bottom: 10),
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
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
                onPressed: onViewDecisions,
                child: const Text('View decisions'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Coach card ──────────────────────────────────────────────────────────────────

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.relationship,
    required this.onRevoke,
  });

  final CoachClientRelationship relationship;
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
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
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

// ── Shared utility cards ────────────────────────────────────────────────────────

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
