import 'package:flutter/material.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:intl/intl.dart';

class InfoStrip extends StatelessWidget {
  const InfoStrip({required this.decision, super.key});

  final Decision decision;

  @override
  Widget build(BuildContext context) {
    final items = <_InfoItem>[
      if (decision.stakes != null)
        _InfoItem(icon: Icons.bolt_outlined, label: decision.stakes!),
      if (decision.categoryName != null)
        _InfoItem(
            icon: Icons.label_outline, label: decision.categoryName!),
      _InfoItem(icon: Icons.flag_outlined, label: decision.state),
      if (decision.decisionDeadline != null)
        _InfoItem(
          icon: Icons.calendar_today_outlined,
          label: DateFormat('d MMM yy')
              .format(decision.decisionDeadline!.toLocal()),
        ),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.label,
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _InfoItem {
  const _InfoItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
