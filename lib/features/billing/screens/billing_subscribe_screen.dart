import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/subscription_status_provider.dart';
import 'package:reflect_os/features/auth/providers/auth_action_provider.dart';
import 'package:reflect_os/features/billing/providers/billing_provider.dart';
import 'package:url_launcher/url_launcher.dart';

const _individualMonthly =
    String.fromEnvironment('STRIPE_INDIVIDUAL_MONTHLY_PRICE_ID');
const _individualAnnual =
    String.fromEnvironment('STRIPE_INDIVIDUAL_ANNUAL_PRICE_ID');
const _teamMonthly =
    String.fromEnvironment('STRIPE_TEAM_MONTHLY_PRICE_ID');
const _teamAnnual =
    String.fromEnvironment('STRIPE_TEAM_ANNUAL_PRICE_ID');

class BillingSubscribeScreen extends ConsumerStatefulWidget {
  const BillingSubscribeScreen({super.key});

  @override
  ConsumerState<BillingSubscribeScreen> createState() =>
      _BillingSubscribeScreenState();
}

class _BillingSubscribeScreenState
    extends ConsumerState<BillingSubscribeScreen> {
  bool _annualBilling = false;
  bool _isCheckingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Uri.base.queryParameters['success'] == 'true') {
        ref.invalidate(subscriptionStatusProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Subscription activated! Welcome to Reflect OS.'),
            ),
          );
        }
      }
    });
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
                successUrl: 'https://app.reflect-os.com/#/settings/billing?success=true',
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SvgPicture.asset(
              isDark
                  ? 'assets/images/reflect-icon-dark.svg'
                  : 'assets/images/reflect-icon-light.svg',
              height: 160,
            ),
            const SizedBox(width: 8),
            const Text('Choose a Plan'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () =>
                ref.read(authActionProvider.notifier).signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Monthly / Annual toggle ────────────────────────────
          Card(
            color: Theme.of(context).colorScheme.surface,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Text('Monthly'),
                  const Spacer(),
                  Switch(
                    value: _annualBilling,
                    onChanged: (v) => setState(() => _annualBilling = v),
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
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Individual ────────────────────────────────────────
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

          // ── Team ──────────────────────────────────────────────
          _PricingCard(
            name: 'Team',
            price: _annualBilling ? '£1,490/yr' : '£149/mo',
            priceNote: _annualBilling
                ? '£124.17/mo billed annually — min 5 seats'
                : 'Billed monthly — min 5 seats',
            features: const [
              'Everything in Individual',
              'Team workspace',
              'Approval workflows',
              'Audit log',
              'Workspace branding',
            ],
            isHighlighted: true,
            isLoading: _isCheckingOut,
            onSubscribe: () => _subscribe(
              _annualBilling ? _teamAnnual : _teamMonthly,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Pricing Card ───────────────────────────────────────────────────────────────

class _PricingCard extends StatelessWidget {
  const _PricingCard({
    required this.name,
    required this.price,
    required this.priceNote,
    required this.features,
    required this.isLoading,
    required this.onSubscribe,
    this.isHighlighted = false,
  });

  final String name;
  final String price;
  final String priceNote;
  final List<String> features;
  final bool isLoading;
  final VoidCallback onSubscribe;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isHighlighted
            ? const BorderSide(color: AppColors.accentPrimary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (isHighlighted) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentPrimary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Popular',
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.accentHover,
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                  ),
                ],
              ],
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
                    Text(f,
                        style: Theme.of(context).textTheme.bodySmall),
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
