import 'package:flutter/material.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/features/decisions/data/models/decision_lens_data.dart';

class InfluenceNodeCard extends StatelessWidget {
  const InfluenceNodeCard({required this.node, super.key});

  final InfluenceNode node;

  Color get _accentColor => switch (node.type) {
        'stakeholder' => AppColors.accentPrimary,
        'risk' => AppColors.destructive,
        'evidence' => AppColors.success,
        'outcome' => AppColors.warning,
        _ => AppColors.textMuted,
      };

  IconData get _icon => switch (node.type) {
        'stakeholder' => Icons.person_outline,
        'risk' => Icons.warning_amber_outlined,
        'evidence' => Icons.attach_file_outlined,
        'outcome' => Icons.check_circle_outline,
        _ => Icons.circle_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        border: Border(
          left: BorderSide(color: _accentColor, width: 3),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Icon(_icon, size: 18, color: _accentColor),
        title: Text(
          node.label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: node.subtitle != null
            ? Text(
                node.subtitle!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              )
            : null,
      ),
    );
  }
}
