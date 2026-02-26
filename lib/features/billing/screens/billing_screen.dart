import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/features/billing/data/models/subscription.dart';
import 'package:reflect_os/features/billing/providers/billing_provider.dart';

final _dateFmt = DateFormat('d MMM yyyy');

class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionAsync = ref.watch(subscriptionProvider);

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
            const Text('Billing'),
          ],
        ),
      ),
      body: subscriptionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load subscription: $e',
                textAlign: TextAlign.center),
          ),
        ),
        data: (sub) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CurrentPlanCard(subscription: sub),
            const SizedBox(height: 24),
            _PlansSection(currentTier: sub?.tier),
          ],
        ),
      ),
    );
  }
}

// ── Current Plan Card ─────────────────────────────────────────────────────────

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.subscription});

  final Subscription? subscription;

  @override
  Widget build(BuildContext context) {
    final sub = subscription;

    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CURRENT PLAN',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 12),
            if (sub == null)
              Text('No active subscription',
                  style: Theme.of(context).textTheme.bodyMedium)
            else ...[
              Row(
                children: [
                  _TierBadge(tier: sub.tierDisplayName),
                  const SizedBox(width: 8),
                  _StatusBadge(status: sub.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Renews ${_dateFmt.format(sub.currentPeriodEnd.toLocal())}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              if (sub.isCancelling) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_outlined,
                          size: 16, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cancels on ${_dateFmt.format(sub.currentPeriodEnd.toLocal())} — your access continues until then.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Tooltip(
                message: sub.stripeCustomerId == null
                    ? 'Stripe not configured'
                    : '',
                child: FilledButton.icon(
                  onPressed: sub.stripeCustomerId != null ? () {} : null,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Manage Billing'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Plans Section ─────────────────────────────────────────────────────────────

class _PlansSection extends StatelessWidget {
  const _PlansSection({required this.currentTier});

  final String? currentTier;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'PLANS',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            const Spacer(),
            Text(
              'Save 15% with annual billing',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.accentHover),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PlanCard(
          tier: 'individual',
          displayName: 'Individual',
          monthlyPrice: '£49/mo',
          annualPrice: '£490/yr',
          description: 'For solo decision-makers.',
          currentTier: currentTier,
        ),
        const SizedBox(height: 10),
        _PlanCard(
          tier: 'team',
          displayName: 'Team',
          monthlyPrice: '£149/mo',
          annualPrice: '£1,490/yr',
          description: 'For teams. Minimum 5 seats.',
          currentTier: currentTier,
        ),
        const SizedBox(height: 10),
        _PlanCard(
          tier: 'enterprise',
          displayName: 'Enterprise',
          monthlyPrice: 'Custom pricing',
          annualPrice: null,
          description: 'Unlimited seats, SSO, dedicated support.',
          currentTier: currentTier,
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.tier,
    required this.displayName,
    required this.monthlyPrice,
    this.annualPrice,
    required this.description,
    required this.currentTier,
  });

  final String tier;
  final String displayName;
  final String monthlyPrice;
  final String? annualPrice;
  final String description;
  final String? currentTier;

  bool get _isCurrent =>
      currentTier?.toLowerCase() == tier.toLowerCase();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: _isCurrent
            ? const BorderSide(color: AppColors.accentPrimary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (_isCurrent) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentPrimary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Current',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.accentHover,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              annualPrice != null
                  ? '$monthlyPrice  ·  $annualPrice'
                  : monthlyPrice,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
            ),
            if (!_isCurrent) ...[
              const SizedBox(height: 12),
              Tooltip(
                message: 'Contact support to upgrade',
                child: FilledButton.tonal(
                  onPressed: null,
                  child: const Text('Upgrade'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Badges ────────────────────────────────────────────────────────────────────

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier});
  final String tier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        tier,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.accentHover,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  Color get _bg => switch (status.toLowerCase()) {
        'active' => AppColors.success.withValues(alpha: 0.2),
        'cancelled' || 'canceled' => AppColors.destructive.withValues(alpha: 0.2),
        _ => AppColors.textMuted.withValues(alpha: 0.2),
      };

  Color get _fg => switch (status.toLowerCase()) {
        'active' => AppColors.success,
        'cancelled' || 'canceled' => AppColors.destructive,
        _ => AppColors.textSecondary,
      };

  String get _label => switch (status.toLowerCase()) {
        'active' => 'Active',
        'cancelled' || 'canceled' => 'Cancelled',
        _ => status,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
