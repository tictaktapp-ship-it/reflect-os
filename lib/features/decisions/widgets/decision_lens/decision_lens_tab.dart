import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/decisions/data/models/decision_lens_data.dart';
import 'package:reflect_os/features/decisions/providers/decision_lens_provider.dart';
import 'package:reflect_os/features/decisions/widgets/decision_lens/arc_painter.dart';
import 'package:reflect_os/features/decisions/widgets/decision_lens/dial_painter.dart';
import 'package:reflect_os/features/decisions/widgets/decision_lens/influence_node_card.dart';
import 'package:reflect_os/features/decisions/widgets/decision_lens/info_strip.dart';
import 'package:reflect_os/features/decisions/widgets/decision_lens/score_breakdown.dart';

class DecisionLensTab extends ConsumerStatefulWidget {
  const DecisionLensTab({required this.decision, super.key});

  final Decision decision;

  @override
  ConsumerState<DecisionLensTab> createState() => _DecisionLensTabState();
}

class _DecisionLensTabState extends ConsumerState<DecisionLensTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lensAsync =
        ref.watch(decisionLensProvider(widget.decision.id));

    return lensAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Could not compute lens data: $e',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
      ),
      data: (lens) => AnimatedBuilder(
        animation: _animation,
        builder: (context, _) =>
            _LensContent(
              decision: widget.decision,
              lens: lens,
              animationValue: _animation.value,
            ),
      ),
    );
  }
}

class _LensContent extends StatelessWidget {
  const _LensContent({
    required this.decision,
    required this.lens,
    required this.animationValue,
  });

  final Decision decision;
  final DecisionLensData lens;
  final double animationValue;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        // ── Info strip ────────────────────────────────────────────────
        InfoStrip(decision: decision),
        const SizedBox(height: 20),

        // ── Gauges row ────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _GaugeCard(
                child: SizedBox(
                  height: 120,
                  child: CustomPaint(
                    painter: ArcPainter(
                      value: lens.confidenceScore / 10,
                      animationValue: animationValue,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GaugeCard(
                child: SizedBox(
                  height: 120,
                  child: CustomPaint(
                    painter: DialPainter(
                      value: lens.healthScore,
                      animationValue: animationValue,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Score breakdown ───────────────────────────────────────────
        _SectionHeader(title: 'Score Breakdown'),
        const SizedBox(height: 10),
        ScoreBreakdown(components: lens.scoreComponents),
        const SizedBox(height: 20),

        // ── Influence web ─────────────────────────────────────────────
        if (lens.influenceNodes.isNotEmpty) ...[
          _SectionHeader(title: 'Influence Web'),
          const SizedBox(height: 4),
          Text(
            'Factors shaping this decision',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 10),
          ...lens.influenceNodes.map(
            (node) => InfluenceNodeCard(node: node),
          ),
        ] else
          Text(
            'No stakeholders, risks, or evidence attached yet.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
      ],
    );
  }
}

class _GaugeCard extends StatelessWidget {
  const _GaugeCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.6),
            letterSpacing: 0.5,
          ),
    );
  }
}
