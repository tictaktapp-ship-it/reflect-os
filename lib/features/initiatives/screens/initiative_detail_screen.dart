import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/initiatives/data/models/initiative.dart';
import 'package:reflect_os/features/initiatives/providers/initiatives_provider.dart';

class InitiativeDetailScreen extends ConsumerWidget {
  const InitiativeDetailScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initiativeAsync = ref.watch(initiativeDetailProvider(id));

    return initiativeAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load: $e', textAlign: TextAlign.center),
          ),
        ),
      ),
      data: (initiative) {
        if (initiative == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Initiative not found.')),
          );
        }
        return _InitiativeDetail(initiative: initiative);
      },
    );
  }
}

// ── Detail body ────────────────────────────────────────────────────────────────

class _InitiativeDetail extends ConsumerWidget {
  const _InitiativeDetail({required this.initiative});

  final Initiative initiative;

  static final _dateFmt = DateFormat('d MMM yyyy');

  String _formatDate(DateTime dt) => _dateFmt.format(dt.toLocal());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decisionsAsync =
        ref.watch(decisionsForInitiativeProvider(initiative.id));

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
              child: Text(initiative.name, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Description ──────────────────────────────────────────────
          _DetailCard(children: [
            _DetailRow(
              label: 'Description',
              value: (initiative.descriptionEncrypted?.isNotEmpty ?? false)
                  ? initiative.descriptionEncrypted!
                  : '—',
            ),
          ]),

          // ── Dates ────────────────────────────────────────────────────
          _DetailCard(children: [
            _DetailRow(
              label: 'Created',
              value: _formatDate(initiative.createdAt),
            ),
            const SizedBox(height: 12),
            _DetailRow(
              label: 'Updated',
              value: _formatDate(initiative.updatedAt),
            ),
          ]),

          // ── Linked decisions ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 8, left: 4),
            child: Text(
              'Linked Decisions',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          ...decisionsAsync.when(
            loading: () => [
              const _DetailCard(children: [
                Center(child: CircularProgressIndicator()),
              ]),
            ],
            error: (e, _) => [
              _DetailCard(children: [
                Text('Failed to load decisions: $e'),
              ]),
            ],
            data: (decisions) {
              if (decisions.isEmpty) {
                return [
                  _DetailCard(children: [
                    Text(
                      'No decisions linked to this initiative.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ]),
                ];
              }
              return decisions
                  .map((d) => _LinkedDecisionTile(decision: d))
                  .toList();
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Detail card ────────────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.backgroundSurface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

// ── Detail row ─────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

// ── Linked decision tile ───────────────────────────────────────────────────────

class _LinkedDecisionTile extends StatelessWidget {
  const _LinkedDecisionTile({required this.decision});

  final Decision decision;

  Color _badgeBackground(String state) => switch (state.toLowerCase()) {
        'active' => AppColors.accentPrimary.withValues(alpha: 0.2),
        'draft' => AppColors.textMuted.withValues(alpha: 0.2),
        'closed' => AppColors.success.withValues(alpha: 0.2),
        'archived' => AppColors.textMuted.withValues(alpha: 0.15),
        _ => AppColors.textMuted.withValues(alpha: 0.2),
      };

  Color _badgeForeground(String state) => switch (state.toLowerCase()) {
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
        onTap: () =>
            context.push('/decisions/detail/${decision.id}'),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _badgeBackground(decision.state),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  decision.state,
                  style:
                      Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _badgeForeground(decision.state),
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
