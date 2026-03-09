import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
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

  /// Builds the text returned to the caller in picker mode.
  /// Prefers the narrative; falls back to formatted summary outputs.
  String _buildAttachmentText() {
    if (widget.result.narrative.isNotEmpty) return widget.result.narrative;
    if (widget.result.summaryOutputs.isNotEmpty) {
      return widget.result.summaryOutputs.entries
          .map((e) => '${e.key}: ${_formatValue(e.value, null)}')
          .join('\n');
    }
    return widget.tool.name;
  }

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

    final bool pickerMode =
        GoRouterState.of(context).uri.queryParameters['pickerMode'] == 'true';

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

          // Section 5 — Chart
          if (chartConfig.isNotEmpty && result.annualProjections.isNotEmpty) ...[
            _SectionHeader(title: 'Chart'),
            _ToolChart(
              chartConfig: chartConfig,
              projections: result.annualProjections
                  .map((r) => r as Map<String, dynamic>)
                  .toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Section 6 — Picker mode: attach output back to decision form
          if (pickerMode) ...[
            _SectionHeader(title: 'Attach to Decision'),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.attach_file, size: 16),
                label: const Text('Attach this output'),
                onPressed: () => context.pop(_buildAttachmentText()),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Section 7 — Inject to decision (only when linked to an existing decision)
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

// ── Tool chart ────────────────────────────────────────────────────────────────

class _ToolChart extends StatelessWidget {
  const _ToolChart({
    required this.chartConfig,
    required this.projections,
  });

  final Map<String, dynamic> chartConfig;
  final List<Map<String, dynamic>> projections;

  // ── Pure helpers ──────────────────────────────────────────────────────────

  static List<Map<String, dynamic>>? _parseSeries(List<dynamic> raw) {
    try {
      return raw.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      return null;
    }
  }

  List<double> _valsFor(Map<String, dynamic> s) {
    final key = s['key'] as String?;
    if (key == null) return [];
    return projections
        .map((row) => ((row[key] as num?) ?? 0).toDouble())
        .toList();
  }

  String _xLabel(int i) {
    if (i < projections.length) {
      final yr = projections[i]['year'];
      if (yr != null) return yr.toString();
    }
    return 'Y${i + 1}';
  }

  // ── Shared chart helpers ──────────────────────────────────────────────────

  static Widget _card(BuildContext context, Widget child) => Card(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: child,
        ),
      );

  static FlGridData _lineGrid(BuildContext context) => FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07),
          strokeWidth: 1,
        ),
      );

  FlTitlesData _lineTitles(BuildContext context, int maxPoints) {
    final rotate = maxPoints > 6;
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 52,
          getTitlesWidget: (v, _) => Text(
            _fmtShort(v),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9),
          ),
        ),
      ),
      rightTitles: const AxisTitles(),
      topTitles: const AxisTitles(),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: rotate ? 36 : 20,
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (v != i.toDouble() || i < 0 || i >= maxPoints) {
              return const SizedBox.shrink();
            }
            final lbl = _xLabel(i);
            if (rotate) {
              return Transform.rotate(
                angle: -math.pi / 4,
                child: Text(lbl,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(fontSize: 9)),
              );
            }
            return Text(lbl,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(fontSize: 9));
          },
        ),
      ),
    );
  }

  // ── Dispatch ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final chartType = chartConfig['primary_chart'] as String?;
    final rawSeries = chartConfig['series'] as List<dynamic>? ?? [];
    if (projections.isEmpty) {
      return const Center(child: Text('No data'));
    }
    return switch (chartType) {
      'cumulative_line'     => _cumulativeLine(context, rawSeries),
      'breakeven_crossover' => _breakevenCrossover(context, rawSeries),
      'fan_chart'           => _fanChart(context, rawSeries),
      'tornado'             => _tornado(context, rawSeries),
      'risk_heatmap'        => _heatmap(context, rawSeries),
      _                     => const Center(child: Text('Chart type not supported')),
    };
  }

  // ── cumulative_line ───────────────────────────────────────────────────────

  Widget _cumulativeLine(BuildContext context, List<dynamic> rawSeries) {
    final series = _parseSeries(rawSeries);
    if (series == null) return const Center(child: Text('No data'));
    final cs      = Theme.of(context).colorScheme;
    final palette = [cs.primary, cs.secondary, cs.tertiary];

    int    maxPoints = 0;
    double maxY      = 0;
    final  lines     = <LineChartBarData>[];

    for (var i = 0; i < series.length; i++) {
      final vals = _valsFor(series[i]);
      if (vals.isEmpty) continue;
      maxPoints = math.max(maxPoints, vals.length);
      double cum = 0;
      final spots = <FlSpot>[];
      for (var j = 0; j < vals.length; j++) {
        cum += vals[j];
        spots.add(FlSpot(j.toDouble(), cum));
        maxY = math.max(maxY, cum.abs());
      }
      lines.add(LineChartBarData(
        spots:   spots,
        isCurved: true,
        color:   palette[i % palette.length],
        barWidth: 2,
        dotData: const FlDotData(show: false),
      ));
    }

    if (lines.isEmpty) return const Center(child: Text('No data'));
    return _card(
      context,
      SizedBox(
        height: 220,
        child: LineChart(LineChartData(
          minY:        0,
          maxY:        maxY * 1.25,
          borderData:  FlBorderData(show: false),
          gridData:    _lineGrid(context),
          titlesData:  _lineTitles(context, maxPoints),
          lineBarsData: lines,
        )),
      ),
    );
  }

  // ── breakeven_crossover ───────────────────────────────────────────────────

  Widget _breakevenCrossover(BuildContext context, List<dynamic> rawSeries) {
    final series = _parseSeries(rawSeries);
    if (series == null || series.length < 2) {
      return const Center(child: Text('No data'));
    }
    final cs       = Theme.of(context).colorScheme;
    final revVals  = _valsFor(series[0]);
    final costVals = _valsFor(series[1]);
    if (revVals.isEmpty || costVals.isEmpty) {
      return const Center(child: Text('No data'));
    }

    final maxPoints = math.max(revVals.length, costVals.length);
    double maxY = 0;
    for (final v in [...revVals, ...costVals]) {
      maxY = math.max(maxY, v.abs());
    }

    int? crossX;
    for (var i = 0; i < math.min(revVals.length, costVals.length) - 1; i++) {
      if ((revVals[i] - costVals[i]) * (revVals[i + 1] - costVals[i + 1]) <= 0) {
        crossX = i;
        break;
      }
    }

    FlSpot toSpot(MapEntry<int, double> e) => FlSpot(e.key.toDouble(), e.value);

    return _card(
      context,
      SizedBox(
        height: 220,
        child: LineChart(LineChartData(
          maxY:       maxY * 1.25,
          borderData: FlBorderData(show: false),
          gridData:   _lineGrid(context),
          titlesData: _lineTitles(context, maxPoints),
          extraLinesData: ExtraLinesData(
            verticalLines: crossX != null
                ? [
                    VerticalLine(
                      x:           crossX.toDouble() + 0.5,
                      color:       cs.onSurface.withValues(alpha: 0.4),
                      strokeWidth: 1.5,
                      dashArray:   [4, 4],
                    )
                  ]
                : [],
          ),
          lineBarsData: [
            LineChartBarData(
              spots:    revVals.asMap().entries.map(toSpot).toList(),
              isCurved: true,
              color:    cs.primary,
              barWidth: 2,
              dotData:  const FlDotData(show: false),
            ),
            LineChartBarData(
              spots:    costVals.asMap().entries.map(toSpot).toList(),
              isCurved: true,
              color:    cs.error,
              barWidth: 2,
              dotData:  const FlDotData(show: false),
            ),
          ],
        )),
      ),
    );
  }

  // ── fan_chart ─────────────────────────────────────────────────────────────

  Widget _fanChart(BuildContext context, List<dynamic> rawSeries) {
    final series = _parseSeries(rawSeries);
    if (series == null || series.length < 3) {
      return const Center(child: Text('No data'));
    }
    final cs = Theme.of(context).colorScheme;

    // Identify base, upper, lower by label; fall back to index 0/1/2
    Map<String, dynamic>? base, upper, lower;
    for (final s in series) {
      final lbl = (s['label'] as String? ?? '').toLowerCase();
      if (lbl.contains('upper') || lbl.contains('best')) {
        upper ??= s;
      } else if (lbl.contains('lower') || lbl.contains('worst')) {
        lower ??= s;
      } else {
        base ??= s;
      }
    }
    base  ??= series[0];
    upper ??= series[1];
    lower ??= series[2];

    final baseVals  = _valsFor(base);
    final upperVals = _valsFor(upper);
    final lowerVals = _valsFor(lower);
    if (baseVals.isEmpty) return const Center(child: Text('No data'));

    final maxPoints = [baseVals.length, upperVals.length, lowerVals.length]
        .reduce(math.max);
    final allVals = [...baseVals, ...upperVals, ...lowerVals];
    final maxY    = allVals.reduce(math.max) * 1.25;
    final rawMin  = allVals.reduce(math.min);
    final minY    = rawMin < 0 ? rawMin * 1.25 : rawMin * 0.75;

    FlSpot toSpot(MapEntry<int, double> e) => FlSpot(e.key.toDouble(), e.value);

    return _card(
      context,
      SizedBox(
        height: 220,
        child: LineChart(LineChartData(
          minY:        minY,
          maxY:        maxY,
          borderData:  FlBorderData(show: false),
          gridData:    _lineGrid(context),
          titlesData:  _lineTitles(context, maxPoints),
          betweenBarsData: upperVals.isNotEmpty && lowerVals.isNotEmpty
              ? [
                  BetweenBarsData(
                    fromIndex: 0,
                    toIndex:   2,
                    color: cs.primary.withValues(alpha: 0.08),
                  )
                ]
              : [],
          lineBarsData: [
            // Upper bound — index 0 (referenced by betweenBarsData)
            LineChartBarData(
              spots:    upperVals.asMap().entries.map(toSpot).toList(),
              isCurved: true,
              color:    cs.primary.withValues(alpha: 0.35),
              barWidth: 1.5,
              dotData:  const FlDotData(show: false),
            ),
            // Base — index 1
            LineChartBarData(
              spots:    baseVals.asMap().entries.map(toSpot).toList(),
              isCurved: true,
              color:    cs.primary,
              barWidth: 2.5,
              dotData:  const FlDotData(show: false),
            ),
            // Lower bound — index 2 (referenced by betweenBarsData)
            LineChartBarData(
              spots:    lowerVals.asMap().entries.map(toSpot).toList(),
              isCurved: true,
              color:    cs.primary.withValues(alpha: 0.35),
              barWidth: 1.5,
              dotData:  const FlDotData(show: false),
            ),
          ],
        )),
      ),
    );
  }

  // ── tornado (horizontal bar, custom layout) ───────────────────────────────

  Widget _tornado(BuildContext context, List<dynamic> rawSeries) {
    final series = _parseSeries(rawSeries);
    if (series == null || series.isEmpty) {
      return const Center(child: Text('No data'));
    }
    final cs = Theme.of(context).colorScheme;

    double firstVal(Map<String, dynamic> s) {
      final vals = _valsFor(s);
      return vals.isNotEmpty ? vals.first : 0.0;
    }

    final labels = series.map((s) => s['label'] as String? ?? '').toList();
    final values = series.map((s) => firstVal(s)).toList();
    double maxAbs = values.map((v) => v.abs()).fold(0.0, math.max);
    if (maxAbs == 0) maxAbs = 1;

    const labelWidth   = 100.0;
    const gapWidth     = 4.0;
    const dividerWidth = 1.0;
    const rowHeight    = 36.0;
    const barHeight    = 24.0;
    final chartHeight  = math.max(180.0, series.length * rowHeight);

    return _card(
      context,
      SizedBox(
        height: chartHeight,
        child: LayoutBuilder(builder: (ctx, constraints) {
          final barAreaWidth =
              (constraints.maxWidth - labelWidth - gapWidth - dividerWidth) / 2;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(series.length, (i) {
              final v    = values[i];
              final frac = v.abs() / maxAbs;
              final posW = v >= 0
                  ? (barAreaWidth * frac).clamp(0.0, barAreaWidth)
                  : 0.0;
              final negW = v < 0
                  ? (barAreaWidth * frac).clamp(0.0, barAreaWidth)
                  : 0.0;
              return SizedBox(
                height: rowHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: labelWidth,
                      child: Text(
                        labels[i],
                        textAlign: TextAlign.right,
                        overflow:  TextOverflow.ellipsis,
                        style: Theme.of(ctx)
                            .textTheme
                            .labelSmall
                            ?.copyWith(fontSize: 9),
                      ),
                    ),
                    SizedBox(width: gapWidth),
                    // Negative half — bar extends rightward from right edge
                    SizedBox(
                      width: barAreaWidth,
                      height: barHeight,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width:  negW,
                          height: barHeight,
                          color:  cs.error.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    Container(
                      width:  dividerWidth,
                      height: barHeight,
                      color:  cs.onSurface.withValues(alpha: 0.2),
                    ),
                    // Positive half — bar extends leftward from left edge
                    SizedBox(
                      width: barAreaWidth,
                      height: barHeight,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width:  posW,
                          height: barHeight,
                          color:  cs.primary.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  // ── risk_heatmap (DataTable) ──────────────────────────────────────────────

  Widget _heatmap(BuildContext context, List<dynamic> rawSeries) {
    final series = _parseSeries(rawSeries);
    if (series == null || series.isEmpty) {
      return const Center(child: Text('No data'));
    }
    final cs = Theme.of(context).colorScheme;

    final allVals = series.expand((s) => _valsFor(s)).toList();
    if (allVals.isEmpty) return const Center(child: Text('No data'));

    final minVal = allVals.reduce(math.min);
    final maxVal = allVals.reduce(math.max);
    final range  = maxVal - minVal;

    Color cellColor(double v) {
      if (range == 0) return cs.primary.withValues(alpha: 0.1);
      final t = (v - minVal) / range; // 0 = low, 1 = high
      if (t < 0.5) {
        return Color.lerp(
          Colors.green.withValues(alpha: 0.25),
          Colors.amber.withValues(alpha: 0.25),
          t * 2,
        )!;
      }
      return Color.lerp(
        Colors.amber.withValues(alpha: 0.25),
        Colors.red.withValues(alpha: 0.25),
        (t - 0.5) * 2,
      )!;
    }

    final maxCols = series.map((s) => _valsFor(s).length).fold(0, math.max);

    return Card(
      color: cs.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor:
              WidgetStatePropertyAll(cs.primary.withValues(alpha: 0.08)),
          columns: [
            const DataColumn(label: Text('Factor')),
            ...List.generate(maxCols, (i) => DataColumn(label: Text('${i + 1}'))),
          ],
          rows: series.map((s) {
            final label = s['label'] as String? ?? '';
            final vals  = _valsFor(s);
            return DataRow(cells: [
              DataCell(Text(label,
                  style: Theme.of(context).textTheme.labelSmall)),
              ...List.generate(maxCols, (i) {
                if (i >= vals.length) return const DataCell(Text('—'));
                final v = vals[i];
                return DataCell(
                  Container(
                    color:   cellColor(v),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: Text(
                      _formatValue(v, null),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                );
              }),
            ]);
          }).toList(),
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

String _fmtShort(double v) {
  if (v.abs() >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v.abs() >= 1000)    return '${(v / 1000).toStringAsFixed(0)}k';
  return v.toStringAsFixed(0);
}
