import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/routing/routes.dart';
import '../data/models/tool_definition.dart';

/// Displays the computed outputs from a tool run.
///
/// Receives all data via [GoRouterState.extra] as a [Map<String, dynamic>]
/// with keys: toolRunId, outputs, tool, decisionId?.
class ToolResultsScreen extends StatelessWidget {
  const ToolResultsScreen({
    super.key,
    required this.toolRunId,
    required this.outputs,
    required this.tool,
    this.decisionId,
  });

  final String toolRunId;
  final Map<String, dynamic> outputs;
  final ToolDefinition tool;
  final String? decisionId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Build ordered list of output fields (sorted by displayOrder)
    final outputFields = List.of(tool.outputSchema)
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            tool.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Calculated results',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            color: theme.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (outputFields.isEmpty)
                    ...outputs.entries.map(
                      (e) => _ResultRow(
                        label: e.key,
                        value: _format(e.value),
                        unit: null,
                      ),
                    )
                  else
                    ...outputFields.map((f) {
                      final value = outputs[f.id];
                      return _ResultRow(
                        label: f.label,
                        value: value == null ? '—' : _format(value),
                        unit: f.unit,
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (decisionId != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back to decision'),
                onPressed: () {
                  final path = Routes.decisionsDetail
                      .replaceFirst(':id', decisionId!);
                  context.go(path);
                },
              ),
            ),
        ],
      ),
    );
  }

  static String _format(dynamic value) {
    if (value == null) return '—';
    if (value is double) {
      if (value == value.truncateToDouble()) {
        return value.toStringAsFixed(0);
      }
      return value.toStringAsFixed(2);
    }
    return value.toString();
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unit != null ? '$value $unit' : value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
