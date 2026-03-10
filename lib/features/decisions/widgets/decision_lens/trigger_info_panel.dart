import 'package:flutter/material.dart';
import 'package:reflect_os/features/decisions/data/models/decision_lens_data.dart';
import 'package:reflect_os/features/decisions/widgets/decision_lens/trigger_utils.dart';

/// Animated panel that slides open below the arc when a trigger is tapped.
/// Pass [trigger] == null to collapse. Never overlaps the arc — uses
/// AnimatedSize so adjacent content reflows smoothly.
class TriggerInfoPanel extends StatelessWidget {
  const TriggerInfoPanel({
    super.key,
    required this.trigger,
    required this.onClose,
  });

  final ConfidenceTrigger? trigger;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = trigger;

    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: t == null
          ? const SizedBox.shrink()
          : Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: triggerColor(t.triggerType)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          triggerLabel(t.triggerType),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.06,
                            color: triggerColor(t.triggerType),
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: onClose,
                        child: Icon(Icons.close, size: 18, color: cs.outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  if (t.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      t.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                        height: 1.55,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        _formatDate(t.triggerDate),
                        style: TextStyle(fontSize: 11, color: cs.outline),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Strength ${'●' * t.influenceStrength}${'○' * (5 - t.influenceStrength)}',
                        style: TextStyle(fontSize: 11, color: cs.outline),
                      ),
                      if (t.confidenceDelta != null &&
                          t.confidenceDelta != 0) ...[
                        const SizedBox(width: 16),
                        Text(
                          t.confidenceDelta! > 0
                              ? '↑ +${t.confidenceDelta!.toStringAsFixed(1)}'
                              : '↓ ${t.confidenceDelta!.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: t.confidenceDelta! > 0
                                ? const Color(0xFF1A8C5E)
                                : const Color(0xFFC13333),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day} ${_month(d.month)} \'${d.year % 100}';

  String _month(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];
}
