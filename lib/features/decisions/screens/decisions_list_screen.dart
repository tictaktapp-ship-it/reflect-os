import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';

class DecisionsListScreen extends ConsumerWidget {
  const DecisionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decisionsAsync = ref.watch(decisionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Decisions')),
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
        data: (decisions) {
          if (decisions.isEmpty) {
            return const Center(
              child: Text('No decisions yet'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: decisions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _DecisionTile(decision: decisions[index]),
          );
        },
      ),
    );
  }
}

class _DecisionTile extends StatelessWidget {
  const _DecisionTile({required this.decision});
  final Decision decision;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
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
            _StatusBadge(status: decision.state),
          ],
        ),
      ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  Color _backgroundFor(String status) => switch (status.toLowerCase()) {
        'active' => AppColors.accentPrimary.withValues(alpha: 0.2),
        'draft' => AppColors.textMuted.withValues(alpha: 0.2),
        'closed' => AppColors.success.withValues(alpha: 0.2),
        'archived' => AppColors.textMuted.withValues(alpha: 0.15),
        _ => AppColors.textMuted.withValues(alpha: 0.2),
      };

  Color _foregroundFor(String status) => switch (status.toLowerCase()) {
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
        color: _backgroundFor(status),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _foregroundFor(status),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
