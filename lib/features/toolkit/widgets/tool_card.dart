import 'package:flutter/material.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import '../data/models/tool_definition.dart';
import 'package:reflect_os/core/theme/app_radius.dart';

class ToolCard extends StatelessWidget {
  const ToolCard({
    super.key,
    required this.tool,
    required this.onTap,
  });

  final ToolDefinition tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _resolveIcon(tool.iconName),
                    size: 18,
                    color: AppColors.accentPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tool.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CategoryChip(category: tool.category),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tool.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _resolveIcon(String name) {
  return switch (name) {
    'trending_up'    => Icons.trending_up,
    'trending_down'  => Icons.trending_down,
    'bar_chart'      => Icons.bar_chart,
    'show_chart'     => Icons.show_chart,
    'pie_chart'      => Icons.pie_chart,
    'people'         => Icons.people,
    'person'         => Icons.person,
    'warning'        => Icons.warning_amber_rounded,
    'check_circle'   => Icons.check_circle_outline,
    'schedule'       => Icons.schedule,
    'science'        => Icons.science,
    'psychology'     => Icons.psychology,
    'balance'        => Icons.balance,
    'analytics'      => Icons.analytics,
    'speed'          => Icons.speed,
    'calculate'      => Icons.calculate,
    _                => Icons.calculate,
  };
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.15),
        borderRadius: AppRadius.mdBR,
      ),
      child: Text(
        category,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.accentPrimary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
