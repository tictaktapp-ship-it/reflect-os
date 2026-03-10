import 'package:flutter/material.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/features/decisions/data/models/decision_lens_data.dart';
import 'package:reflect_os/features/decisions/widgets/decision_lens/trigger_utils.dart';

class ScoreBreakdown extends StatelessWidget {
  const ScoreBreakdown({
    required this.components,
    this.triggers = const [],
    super.key,
  });

  final List<ScoreComponent> components;
  final List<ConfidenceTrigger> triggers;

  Color _barColor(double value) {
    if (value >= 0.7) return AppColors.success;
    if (value >= 0.4) return AppColors.warning;
    return AppColors.destructive;
  }

  @override
  Widget build(BuildContext context) {
    // Deduplicate trigger types present in this decision's triggers
    final presentTypes = triggers.map((t) => t.triggerType).toSet().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bars
        ...components.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      c.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    Text(
                      c.displayValue,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: c.value,
                    minHeight: 6,
                    backgroundColor: AppColors.borderSubtle,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _barColor(c.value),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Trigger legend (only shown when there are triggers)
        if (presentTypes.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Causal Signals',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.4,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: presentTypes.map((type) {
              final color = triggerColor(type);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    triggerLabel(type),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
