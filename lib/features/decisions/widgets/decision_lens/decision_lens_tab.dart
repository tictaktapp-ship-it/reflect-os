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
import 'package:reflect_os/features/decisions/widgets/decision_lens/trigger_info_panel.dart';
import 'package:reflect_os/core/theme/app_radius.dart';

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
    final lensAsync = ref.watch(decisionLensProvider(widget.decision.id));

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
        builder: (context, _) => _LensContent(
          decision: widget.decision,
          lens: lens,
          animationValue: _animation.value,
        ),
      ),
    );
  }
}

// ── _LensContent (stateful to own toggle + tap state) ─────────────────────────

class _LensContent extends StatefulWidget {
  const _LensContent({
    required this.decision,
    required this.lens,
    required this.animationValue,
  });

  final Decision decision;
  final DecisionLensData lens;
  final double animationValue;

  @override
  State<_LensContent> createState() => _LensContentState();
}

class _LensContentState extends State<_LensContent> {
  bool _showMarkers = true;
  bool _showBands = true;
  ConfidenceTrigger? _selectedTrigger;
  List<TriggerHitArea> _hitAreas = [];

  @override
  Widget build(BuildContext context) {
    final lens = widget.lens;
    final hasTriggers = lens.triggers.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        // ── Info strip ────────────────────────────────────────────────
        InfoStrip(decision: widget.decision),
        const SizedBox(height: 20),

        // ── Small gauges row (arc + dial) ─────────────────────────────
        Row(
          children: [
            Expanded(
              child: _GaugeCard(
                child: SizedBox(
                  height: 160,
                  child: CustomPaint(
                    painter: ArcPainter(
                      value: lens.confidenceScore / 10,
                      animationValue: widget.animationValue,
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
                  height: 160,
                  child: CustomPaint(
                    painter: DialPainter(
                      value: lens.healthScore,
                      animationValue: widget.animationValue,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Confidence Trajectory (full-width arc with trigger markers) ─
        Row(
          children: [
            Text(
              'Confidence Trajectory',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                    letterSpacing: 0.5,
                  ),
            ),
            const Spacer(),
            if (hasTriggers) ...[
              _ToggleChip(
                label: 'Bands',
                active: _showBands,
                onTap: () => setState(() => _showBands = !_showBands),
              ),
              const SizedBox(width: 6),
              _ToggleChip(
                label: 'Markers',
                active: _showMarkers,
                onTap: () => setState(() {
                  _showMarkers = !_showMarkers;
                  if (!_showMarkers) _selectedTrigger = null;
                }),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        _GaugeCard(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = (w * 0.62).clamp(160.0, 280.0);
              return SizedBox(
                height: h,
                child: GestureDetector(
                  onTapUp: (details) {
                    if (!_showMarkers) return;
                    final localPos = details.localPosition;
                    TriggerHitArea? hit;
                    for (final h in _hitAreas) {
                      if ((localPos - h.center).distance < h.radius + 8) {
                        hit = h;
                        break;
                      }
                    }
                    setState(() {
                      _selectedTrigger =
                          hit?.trigger == _selectedTrigger ? null : hit?.trigger;
                    });
                  },
                  child: CustomPaint(
                    painter: ArcPainter(
                      value: lens.confidenceScore / 10,
                      animationValue: widget.animationValue,
                      triggers: lens.triggers,
                      showTriggerMarkers: _showMarkers,
                      showInfluenceBands: _showBands,
                      showLabel: false,
                      onHitAreasUpdated: (areas) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _hitAreas = areas);
                        });
                      },
                    ),
                    size: Size(w, h),
                  ),
                ),
              );
            },
          ),
        ),

        // ── Trigger info panel ────────────────────────────────────────
        TriggerInfoPanel(
          trigger: _selectedTrigger,
          onClose: () => setState(() => _selectedTrigger = null),
        ),

        const SizedBox(height: 20),

        // ── Score breakdown ───────────────────────────────────────────
        _SectionHeader(title: 'Score Breakdown'),
        const SizedBox(height: 10),
        ScoreBreakdown(
          components: lens.scoreComponents,
          triggers: lens.triggers,
        ),
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

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _GaugeCard extends StatelessWidget {
  const _GaugeCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdBR,
        border: Border.all(color: Colors.black12, width: 0.5),
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

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accentPrimary.withValues(alpha: 0.15)
              : Colors.white,
          borderRadius: AppRadius.smBR,
          border: Border.all(
            color: active ? AppColors.accentPrimary : AppColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.accentPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
