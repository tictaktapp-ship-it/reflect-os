import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/decisions/widgets/quick_log_sheet.dart';
import 'package:reflect_os/features/onboarding/first_run_provider.dart';
import 'package:reflect_os/widgets/reflect_logo.dart';

class FirstRunScreen extends ConsumerWidget {
  const FirstRunScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.cs;
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: cs.backgroundPrimary,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Logo ────────────────────────────────────────────────
                  Align(
                    alignment: Alignment.center,
                    child: ReflectLogo(iconSize: 48),
                  ),
                  const SizedBox(height: 48),

                  // ── Headline ─────────────────────────────────────────────
                  Text(
                    'Welcome to Reflect',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isWide ? 28 : 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'DMSans',
                      color: cs.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Start by logging your first decision.\nIt only takes 30 seconds.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: cs.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // ── Sample decision card (optional) ───────────────────────
                  _SampleDecisionCard(cs: cs),
                  const SizedBox(height: 36),

                  // ── Primary CTA ───────────────────────────────────────────
                  FilledButton.icon(
                    onPressed: () => _openQuickLog(context, ref),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF19CBD6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add_circle_rounded, size: 20),
                    label: const Text(
                      'Log My First Decision',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'DMSans',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Skip link ─────────────────────────────────────────────
                  Center(
                    child: TextButton(
                      onPressed: () => _skip(context, ref),
                      child: Text(
                        'Skip for now',
                        style: TextStyle(
                          color: cs.textTertiary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openQuickLog(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    if (isWide) {
      showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: QuickLogSheet(
                onSaved: () => _onDecisionSaved(context, ref),
              ),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.97,
          builder: (_, controller) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: QuickLogSheet(
              onSaved: () => _onDecisionSaved(context, ref),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _onDecisionSaved(BuildContext context, WidgetRef ref) async {
    await markFirstRunComplete(ref);
    // The sheet will show its own confirmation view with "View decision" / "Log another".
    // Once the user dismisses it they land on the dashboard (gate cleared).
    // We pre-navigate here so the background route is already correct.
    if (context.mounted) context.go(Routes.dashboard);
  }

  Future<void> _skip(BuildContext context, WidgetRef ref) async {
    await markFirstRunComplete(ref);
    if (context.mounted) context.go(Routes.dashboard);
  }
}

// ── Sample decision card ───────────────────────────────────────────────────────

class _SampleDecisionCard extends StatefulWidget {
  const _SampleDecisionCard({required this.cs});

  final AppColorScheme cs;

  @override
  State<_SampleDecisionCard> createState() => _SampleDecisionCardState();
}

class _SampleDecisionCardState extends State<_SampleDecisionCard> {
  Decision? _sample;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _fetchSample();
  }

  Future<void> _fetchSample() async {
    try {
      final rows = await supabase
          .from('user_visible_decisions')
          .select('id, title, state, initial_confidence')
          .eq('is_sample_data', true)
          .limit(1);
      if (!mounted) return;
      if (rows.isNotEmpty) {
        setState(() {
          _sample = Decision.fromJson(rows.first);
          _loaded = true;
        });
      } else {
        setState(() => _loaded = true);
      }
    } catch (_) {
      // Column may not exist — silently hide the card.
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _sample == null) return const SizedBox.shrink();

    final cs = widget.cs;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.backgroundElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  size: 14, color: Color(0xFF19CBD6)),
              const SizedBox(width: 6),
              Text(
                'Example decision',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF19CBD6),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _sample!.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _Pill(label: _sample!.state, cs: cs),
              if (_sample!.initialConfidence != null) ...[
                const SizedBox(width: 8),
                _Pill(
                  label: '${_sample!.initialConfidence! * 10}% confident',
                  cs: cs,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.cs});

  final String label;
  final AppColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.backgroundSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.borderDefault),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: cs.textTertiary),
      ),
    );
  }
}
