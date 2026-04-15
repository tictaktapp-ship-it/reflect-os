import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:reflect_os/widgets/app_header.dart';

class ReferEarnScreen extends StatelessWidget {
  const ReferEarnScreen({super.key});

  static const _reditusUrl =
      'https://app.getreditus.com/referral-program/reflect_os';

  Future<void> _launchDashboard(BuildContext context) async {
    final uri = Uri.parse(_reditusUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open the referral dashboard. Visit app.getreditus.com directly.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: const AppHeader(
        title: 'Refer & Earn',
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero block ──────────────────────────────────────────────
            Column(
              children: [
                Icon(
                  Icons.card_giftcard_outlined,
                  size: 48,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Earn by sharing Reflect OS',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Refer executives, investors and leadership teams. '
                  'Earn 25% of their subscription revenue for 12 months '
                  '— paid automatically via PayPal.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Stat cards ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatCard(value: '25%', label: 'recurring commission'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(value: '£25', label: 'first purchase bonus'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(value: '12 months', label: 'per referral'),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── How it works ────────────────────────────────────────────
            Text(
              'How it works',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const _HowItWorksStep(
              number: '1',
              text: 'Get your unique referral link from the dashboard below',
            ),
            const SizedBox(height: 8),
            const _HowItWorksStep(
              number: '2',
              text: 'Share it with people who would benefit from Reflect OS',
            ),
            const SizedBox(height: 8),
            const _HowItWorksStep(
              number: '3',
              text:
                  'Earn 25% of their subscription for 12 months automatically',
            ),
            const SizedBox(height: 32),

            // ── CTA button ──────────────────────────────────────────────
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Referral Dashboard'),
              onPressed: () => _launchDashboard(context),
            ),
            const SizedBox(height: 24),

            // ── Fine print ──────────────────────────────────────────────
            Text(
              'Referral tracking and payouts are managed by Reditus. '
              "You'll need to create a free Reditus account to access "
              'your dashboard and receive payments.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── How it works step ─────────────────────────────────────────────────────────

class _HowItWorksStep extends StatelessWidget {
  const _HowItWorksStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}
