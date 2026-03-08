import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/providers/subscription_status_provider.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/billing/data/models/subscription.dart';
import 'package:reflect_os/features/billing/providers/billing_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Price IDs (injected at build time) ────────────────────────────────────────

const _individualMonthly =
    String.fromEnvironment('STRIPE_INDIVIDUAL_MONTHLY_PRICE_ID');
const _individualAnnual =
    String.fromEnvironment('STRIPE_INDIVIDUAL_ANNUAL_PRICE_ID');
const _teamMonthly =
    String.fromEnvironment('STRIPE_TEAM_MONTHLY_PRICE_ID');
const _teamAnnual =
    String.fromEnvironment('STRIPE_TEAM_ANNUAL_PRICE_ID');

final _dateFmt = DateFormat('d MMM yyyy');

// ── BillingScreen ──────────────────────────────────────────────────────────────

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  bool _annualBilling = false;
  bool _isCheckingOut = false;
  bool _isManaging = false;

  // Team plan state
  final List<TextEditingController> _emailControllers =
      List.generate(10, (_) => TextEditingController());
  final int _minSeats = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (Uri.base.queryParameters['success'] == 'true') {
        ref.invalidate(subscriptionProvider);
        ref.invalidate(subscriptionStatusProvider);

        // Dispatch pending team invitations if returning from team checkout
        try {
          final prefs = await SharedPreferences.getInstance();
          final pendingEmails = prefs.getStringList('pending_invite_emails');
          final pendingWorkspaceId =
              prefs.getString('pending_invite_workspace');
          final pendingWorkspaceName =
              prefs.getString('pending_invite_workspace_name');

          if (pendingEmails != null &&
              pendingEmails.isNotEmpty &&
              pendingWorkspaceId != null) {
            await prefs.remove('pending_invite_emails');
            await prefs.remove('pending_invite_workspace');
            await prefs.remove('pending_invite_workspace_name');
            await supabase.functions.invoke('send-team-invitations', body: {
              'workspace_id': pendingWorkspaceId,
              'emails': pendingEmails,
              'workspace_name': pendingWorkspaceName ?? 'Your workspace',
            });
          }
        } catch (_) {
          // Non-fatal — invitations can be resent from workspace settings
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscription activated! Welcome to Reflect OS.'),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    for (final c in _emailControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _subscribe(String priceId) async {
    setState(() => _isCheckingOut = true);
    try {
      final workspaceId =
          await ref.read(billingRepositoryProvider).ensureWorkspaceExists();
      final url =
          await ref.read(billingRepositoryProvider).createCheckoutSession(
                priceId: priceId,
                workspaceId: workspaceId,
                successUrl:
                    'https://app.reflect-os.com/#/settings/billing?success=true',
                cancelUrl: 'https://app.reflect-os.com/#/settings/billing',
              );
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      final isNetwork = e.toString().contains('Failed to fetch') ||
          e.toString().contains('XMLHttpRequest') ||
          e.toString().contains('NetworkError');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNetwork
                ? 'Stripe checkout unavailable in this network environment'
                : 'Failed to start checkout: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  Future<void> _startTeamCheckout(List<String> emails) async {
    setState(() => _isCheckingOut = true);
    try {
      final seatCount = max(_minSeats, emails.length);
      final workspaceId =
          await ref.read(billingRepositoryProvider).ensureWorkspaceExists();

      // Persist emails so we can dispatch invitations after Stripe returns
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('pending_invite_emails', emails);
      await prefs.setString('pending_invite_workspace', workspaceId);
      final workspaceName = ref.read(workspaceNameProvider).valueOrNull;
      if (workspaceName != null) {
        await prefs.setString('pending_invite_workspace_name', workspaceName);
      }

      final url = await ref
          .read(billingRepositoryProvider)
          .createTeamCheckoutSession(
            priceId: _annualBilling ? _teamAnnual : _teamMonthly,
            workspaceId: workspaceId,
            seatCount: seatCount,
            invitedEmails: emails,
            successUrl:
                'https://app.reflect-os.com/#/settings/billing?success=true',
            cancelUrl: 'https://app.reflect-os.com/#/settings/billing',
          );
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start checkout: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  Future<void> _manage(String workspaceId) async {
    setState(() => _isManaging = true);
    try {
      final url =
          await ref.read(billingRepositoryProvider).manageSubscription(
                workspaceId: workspaceId,
                returnUrl: 'https://app.reflect-os.com/#/settings/billing',
              );
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open billing portal: $e')),
      );
    } finally {
      if (mounted) setState(() => _isManaging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscriptionAsync = ref.watch(subscriptionProvider);
    final workspaceId = ref.watch(currentWorkspaceProvider).valueOrNull;

    // Computed on every build so UI stays reactive as email fields change
    final validEmails = _emailControllers
        .map((c) => c.text.trim())
        .where((e) => e.contains('@') && e.contains('.'))
        .toList();
    final canProceed = validEmails.length >= _minSeats;

    return Scaffold(
      appBar: AppBar(),
      body: subscriptionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load subscription: $e',
                textAlign: TextAlign.center),
          ),
        ),
        data: (sub) {
          final hasActiveSub = sub != null &&
              (sub.status == 'active' || sub.status == 'trialing');

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (hasActiveSub) ...[
                _ActivePlanCard(
                  subscription: sub,
                  isManaging: _isManaging,
                  onManage: workspaceId != null
                      ? () => _manage(workspaceId)
                      : null,
                ),
              ] else ...[
                // ── Monthly / Annual toggle ──────────────────────
                Card(
                  color: theme.colorScheme.surface,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        const Text('Monthly'),
                        const Spacer(),
                        Switch(
                          value: _annualBilling,
                          onChanged: (v) =>
                              setState(() => _annualBilling = v),
                        ),
                        const SizedBox(width: 4),
                        const Text('Annual'),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Save ~17%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Individual plan ──────────────────────────────
                _PricingCard(
                  name: 'Individual',
                  price: _annualBilling ? '£490/yr' : '£49/mo',
                  priceNote: _annualBilling
                      ? '£40.83/mo billed annually'
                      : 'Billed monthly',
                  features: const [
                    'Personal decisions',
                    'AI risk assessment & debrief',
                    'PDF export',
                    'Share links',
                  ],
                  isLoading: _isCheckingOut,
                  onSubscribe: () => _subscribe(
                    _annualBilling ? _individualAnnual : _individualMonthly,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Unified Team card ────────────────────────────
                Card(
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(
                        color: AppColors.accentPrimary, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          children: [
                            Text(
                              'Team',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accentPrimary
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Popular',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.accentHover,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Pricing headline
                        Text(
                          'from £195/month',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentPrimary,
                          ),
                        ),
                        Text(
                          '£39/user/month · minimum 5 users',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Feature list
                        ...const [
                          'Everything in Individual',
                          'Team workspace',
                          'Approval workflows',
                          'Audit log',
                          'Workspace branding',
                        ].map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline,
                                    size: 16, color: AppColors.success),
                                const SizedBox(width: 8),
                                Text(f,
                                    style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ),

                        const Divider(height: 24),

                        // Team members section header
                        Text(
                          'Team members',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add email addresses. Minimum 5 required.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Email fields
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _emailControllers.length,
                          itemBuilder: (context, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextFormField(
                              controller: _emailControllers[i],
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: i < _minSeats
                                    ? 'Email ${i + 1} *'
                                    : 'Email ${i + 1}',
                                hintText: 'colleague@company.com',
                                prefixIcon:
                                    const Icon(Icons.email_outlined),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),

                        // Add more button
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _emailControllers.add(TextEditingController());
                          }),
                          icon: const Icon(Icons.add),
                          label: const Text('Add another person'),
                        ),

                        const SizedBox(height: 16),

                        // Running total (always visible)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Monthly total',
                                  style: theme.textTheme.bodyMedium),
                              Text(
                                '£${39 * max(_minSeats, validEmails.length)}/month',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accentPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Proceed to payment button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: canProceed && !_isCheckingOut
                                ? () => _startTeamCheckout(validEmails)
                                : null,
                            child: _isCheckingOut
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    canProceed
                                        ? 'Proceed to payment'
                                        : 'Add ${_minSeats - validEmails.length} more email${_minSeats - validEmails.length == 1 ? '' : 's'} to continue',
                                  ),
                          ),
                        ),

                        // Validation hint (only when < 5 valid emails)
                        if (!canProceed)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${_minSeats - validEmails.length} more email address${_minSeats - validEmails.length == 1 ? '' : 'es'} needed',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── Active Plan Card ───────────────────────────────────────────────────────────

class _ActivePlanCard extends StatelessWidget {
  const _ActivePlanCard({
    required this.subscription,
    required this.isManaging,
    this.onManage,
  });

  final Subscription subscription;
  final bool isManaging;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final sub = subscription;
    final periodLabel = sub.cancelAtPeriodEnd ? 'Cancels' : 'Renews';

    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CURRENT PLAN',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _TierBadge(tier: sub.tierDisplayName),
                const SizedBox(width: 8),
                _StatusBadge(status: sub.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$periodLabel ${_dateFmt.format(sub.currentPeriodEnd.toLocal())}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
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
            FilledButton.icon(
              onPressed: isManaging ? null : onManage,
              icon: isManaging
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.open_in_new, size: 16),
              label: const Text('Manage Subscription'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pricing Card (Individual) ──────────────────────────────────────────────────

class _PricingCard extends StatelessWidget {
  const _PricingCard({
    required this.name,
    required this.price,
    required this.priceNote,
    required this.features,
    required this.isLoading,
    this.onSubscribe,
  });

  final String name;
  final String price;
  final String priceNote;
  final List<String> features;
  final bool isLoading;
  final VoidCallback? onSubscribe;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              price,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              priceNote,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
            const SizedBox(height: 14),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 16, color: AppColors.success),
                    const SizedBox(width: 8),
                    Text(f, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isLoading ? null : onSubscribe,
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Subscribe'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Badges ─────────────────────────────────────────────────────────────────────

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
        'trialing' => Colors.blue.withValues(alpha: 0.2),
        'past_due' => AppColors.warning.withValues(alpha: 0.2),
        'canceled' || 'cancelled' || 'unpaid' =>
          AppColors.destructive.withValues(alpha: 0.2),
        _ => AppColors.textMuted.withValues(alpha: 0.2),
      };

  Color get _fg => switch (status.toLowerCase()) {
        'active' => AppColors.success,
        'trialing' => Colors.blue,
        'past_due' => AppColors.warning,
        'canceled' || 'cancelled' || 'unpaid' => AppColors.destructive,
        _ => AppColors.textSecondary,
      };

  String get _label => switch (status.toLowerCase()) {
        'active' => 'Active',
        'trialing' => 'Trialing',
        'past_due' => 'Past Due',
        'canceled' || 'cancelled' => 'Cancelled',
        'unpaid' => 'Unpaid',
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
