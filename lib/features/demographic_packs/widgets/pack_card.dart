import 'package:flutter/material.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import '../data/models/demographic_pack.dart';

class PackCard extends StatelessWidget {
  const PackCard({
    super.key,
    required this.pack,
    required this.isDefault,
    required this.onSetDefault,
    this.settingDefault = false,
  });

  final DemographicPack pack;
  final bool isDefault;
  final VoidCallback onSetDefault;

  /// True while the set-default RPC is in flight.
  final bool settingDefault;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    pack.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isDefault)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Default',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (pack.key.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                pack.key,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.accentPrimary,
                ),
              ),
            ],
            if (pack.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                pack.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            if (!isDefault)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: settingDefault ? null : onSetDefault,
                  child: settingDefault
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Set as default'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
