import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/routing/routes.dart';
import '../data/models/tool_definition.dart';
import '../data/models/tool_run.dart';
import '../data/toolkit_repository.dart';
import '../engine/calculator_engine.dart';

/// Displays computed results for a tool run.
///
/// Receives via [GoRouterState.extra] a Dart record:
/// ```
/// ({ToolCalculationResult result, ToolRun run, ToolDefinition tool, String? decisionId})
/// ```
class ToolResultsScreen extends StatefulWidget {
  const ToolResultsScreen({
    super.key,
    required this.result,
    required this.run,
    required this.tool,
    this.decisionId,
  });

  final ToolCalculationResult result;
  final ToolRun run;
  final ToolDefinition tool;
  final String? decisionId;

  @override
  State<ToolResultsScreen> createState() => _ToolResultsScreenState();
}

class _ToolResultsScreenState extends State<ToolResultsScreen> {
  late final TextEditingController _descCtrl =
      TextEditingController(text: widget.result.narrative);
  bool _attachAudit  = false;
  bool _isInjecting  = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Inject to decision ────────────────────────────────────────────────────

  Future<void> _inject() async {
    final decisionId = widget.decisionId;
    if (decisionId == null) return;

    setState(() => _isInjecting = true);
    try {
      await const ToolkitRepository().approveAndInjectToolOutput(
        toolRunId:                widget.run.id,
        decisionId:               decisionId,
        finalDescription:         _descCtrl.text.trim(),
        outputsJsonb:             widget.result.summaryOutputs,
        calculationBreakdownJsonb: {
          'projections': widget.result.annualProjections,
          'narrative':   widget.result.narrative,
        },
        attachToolAudit: _attachAudit,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Result injected into decision')),
      );
      final path = Routes.decisionsDetail
          .replaceFirst(':id', decisionId);
      context.go(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to inject: $e')));
      }
    } finally {
      if (mounted) setState(() => _isInjecting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme        = Theme.of(context);
    final result       = widget.result;
    final tool         = widget.tool;
    final summaryFields = tool.summaryFields;
    final heroFields    = summaryFields
        .where((f) => (f as Map<String, dynamic>)['is_hero'] == true)
        .toList();
    final nonHeroFields = summaryFields
        .where((f) => (f as Map<String, dynamic>)['is_hero'] != true)
        .toList();
    final projColumns  = tool.annualProjectionColumns;
    final chartConfig  = tool.chartConfig;

    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tool header
          Text(tool.name,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Calculated results',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 20),

          // Section 1 — Hero metrics
          if (heroFields.isNotEmpty) ...[
            _SectionHeader(title: ''),
            _HeroStrip(fields: heroFields, outputs: result.summaryOutputs),
            const SizedBox(height: 20),
          ],

          // Section 2 — Summary grid
          if (nonHeroFields.isNotEmpty) ...[
            _SectionHeader(title: 'Summary'),
            _SummaryGrid(fields: nonHeroFields, outputs: result.summaryOutputs),
            const SizedBox(height: 20),
          ],

          // Fallback: if no output schema, show raw outputs
          if (summaryFields.isEmpty &&
              result.summaryOutputs.isNotEmpty) ...[
            _SectionHeader(title: 'Results'),
            Card(
              color: theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: result.summaryOutputs.entries
                      .map((e) => _ResultRow(
                            label: e.key,
                            value: _formatValue(e.value, null),
                          ))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Section 3 — Narrative
          if (result.narrative.isNotEmpty) ...[
            _SectionHeader(title: 'Summary'),
            _NarrativeCard(
                narrative: result.narrative, iconName: tool.iconName),
            const SizedBox(height: 20),
          ],

          // Section 4 — Annual projections table
          if (projColumns.isNotEmpty &&
              result.annualProjections.isNotEmpty) ...[
            _SectionHeader(title: 'Projections'),
            _ProjectionsTable(
                columns: projColumns,
                rows: result.annualProjections),
            const SizedBox(height: 20),
          ],

          // Section 5 — Chart stub
          if (chartConfig.isNotEmpty) ...[
            _SectionHeader(title: 'Chart'),
            _ChartStub(chartConfig: chartConfig),
            const SizedBox(height: 20),
          ],

          // Section 6 — Inject to decision
          if (widget.decisionId != null) ...[
            _SectionHeader(title: 'Inject to Decision'),
            _InjectCard(
              descController: _descCtrl,
              attachAudit:    _attachAudit,
              isInjecting:    _isInjecting,
              onAuditChanged: (v) => setState(() => _attachAudit = v),
              onInject:       _inject,
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    if (title.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

// ── Hero strip ────────────────────────────────────────────────────────────────

class _HeroStrip extends StatelessWidget {
  const _HeroStrip({required this.fields, required this.outputs});

  final List<dynamic> fields;
  final Map<String, dynamic> outputs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: fields.map((f) {
        final field = f as Map<String, dynamic>;
        final id    = field['id'] as String;
        final label = field['label'] as String? ?? id;
        final type  = field['type'] as String?;
        final raw   = outputs[id];
        final value = _formatValue(raw, type);

        return Expanded(
          child: Card(
            color: AppColors.accentPrimary.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentPrimary,
                      )),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Summary grid ──────────────────────────────────────────────────────────────

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.fields, required this.outputs});

  final List<dynamic> fields;
  final Map<String, dynamic> outputs;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: fields.map((f) {
        final field = f as Map<String, dynamic>;
        final id    = field['id'] as String;
        final label = field['label'] as String? ?? id;
        final type  = field['type'] as String?;
        final raw   = outputs[id];
        final value = _formatValue(raw, type);

        return SizedBox(
          width: (MediaQuery.sizeOf(context).width - 48) / 2,
          child: _ResultRow(label: label, value: value),
        );
      }).toList(),
    );
  }
}

// ── Result row ────────────────────────────────────────────────────────────────

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentPrimary,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Narrative card ────────────────────────────────────────────────────────────

class _NarrativeCard extends StatelessWidget {
  const _NarrativeCard({required this.narrative, required this.iconName});

  final String narrative;
  final String iconName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome, size: 20, color: AppColors.accentPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                narrative,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Projections table ─────────────────────────────────────────────────────────

class _ProjectionsTable extends StatelessWidget {
  const _ProjectionsTable({required this.columns, required this.rows});

  final List<dynamic> columns;
  final List<dynamic> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
              AppColors.accentPrimary.withValues(alpha: 0.08)),
          columns: columns.map((c) {
            final col = c as Map<String, dynamic>;
            return DataColumn(
              label: Text(col['label'] as String? ?? '',
                  style:
                      const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            );
          }).toList(),
          rows: rows.map((r) {
            final row = r as Map<String, dynamic>;
            return DataRow(
              cells: columns.map((c) {
                final col = c as Map<String, dynamic>;
                final id  = col['id'] as String;
                final type = col['type'] as String?;
                final val  = row[id];
                return DataCell(Text(_formatValue(val, type),
                    style: const TextStyle(fontSize: 12)));
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Chart stub ────────────────────────────────────────────────────────────────

class _ChartStub extends StatelessWidget {
  const _ChartStub({required this.chartConfig});

  final Map<String, dynamic> chartConfig;

  static IconData _chartIcon(String? type) => switch (type) {
        'cumulative_line'      => Icons.show_chart,
        'breakeven_crossover'  => Icons.show_chart,
        'fan_chart'            => Icons.area_chart,
        'tornado'              => Icons.bar_chart,
        'risk_heatmap'         => Icons.grid_on,
        _                      => Icons.bar_chart,
      };

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final chartType = chartConfig['primary_chart'] as String?;
    final seriesList = (chartConfig['series'] as List<dynamic>?)
            ?.map((s) => s.toString())
            .join(', ') ??
        '';

    return Card(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(_chartIcon(chartType),
                size: 48, color: AppColors.accentPrimary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              chartType ?? 'Chart',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            if (seriesList.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(seriesList,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 8),
            Text('Charts coming in the next release',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ── Inject card ───────────────────────────────────────────────────────────────

class _InjectCard extends StatelessWidget {
  const _InjectCard({
    required this.descController,
    required this.attachAudit,
    required this.isInjecting,
    required this.onAuditChanged,
    required this.onInject,
  });

  final TextEditingController descController;
  final bool attachAudit;
  final bool isInjecting;
  final void Function(bool) onAuditChanged;
  final VoidCallback onInject;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inject result into decision outcome prediction',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Attach full calculation audit to decision'),
              value: attachAudit,
              onChanged: (v) => onAuditChanged(v ?? false),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isInjecting ? null : onInject,
                child: isInjecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Approve & Insert'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Formatting helper ─────────────────────────────────────────────────────────

String _formatValue(dynamic value, String? type) {
  if (value == null) return '—';
  if (value is bool) return value ? 'Yes' : 'No';

  if (value is num) {
    final d = value.toDouble();
    return switch (type) {
      'currency' => _fmtCurrency(d),
      'percent'  => '${d.toStringAsFixed(1)}%',
      'months'   => '${d.toStringAsFixed(0)} months',
      'number'   => d == d.truncateToDouble()
          ? d.toStringAsFixed(0)
          : d.toStringAsFixed(2),
      _          => d == d.truncateToDouble()
          ? d.toStringAsFixed(0)
          : d.toStringAsFixed(2),
    };
  }

  return value.toString();
}

String _fmtCurrency(double v) {
  if (v.abs() >= 1000000) return '£${(v / 1000000).toStringAsFixed(1)}m';
  if (v.abs() >= 1000)    return '£${(v / 1000).toStringAsFixed(0)}k';
  return '£${v.toStringAsFixed(0)}';
}
