import 'dart:math' as math;
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ── Brand colours ─────────────────────────────────────────────────────────────
const _teal    = PdfColor.fromInt(0xFF19CBD6);
const _darkBg  = PdfColor.fromInt(0xFF1E293B);
const _green   = PdfColor.fromInt(0xFF2EA073);
const _amber   = PdfColor.fromInt(0xFFD97D24);
const _red     = PdfColor.fromInt(0xFFDC4444);
const _textDark   = PdfColor.fromInt(0xFF1E293B);
const _textMuted  = PdfColor.fromInt(0xFF64748B);
const _border     = PdfColor.fromInt(0xFFE2E8F0);
const _rowAlt     = PdfColor.fromInt(0xFFF8FAFC);
const _white      = PdfColors.white;

// ── Top-level entry point for compute() ───────────────────────────────────────

/// Entry point for Flutter's compute() isolate.
Future<Uint8List> generatePdfBackground(Map<String, dynamic> args) =>
    PdfDocumentService().generateToolOutputPdf(
      decisionTitle:     args['decisionTitle'] as String,
      toolName:          args['toolName'] as String,
      toolKey:           args['toolKey'] as String,
      toolOutput:        args['toolOutput'] as String,
      outputs:           (args['outputs'] as Map).cast<String, dynamic>(),
      inputs:            (args['inputs'] as Map).cast<String, dynamic>(),
      projections:       _castList(args['projections'] as List),
      projectionColumns: _castList(args['projectionColumns'] as List),
      currencyCode:      args['currencyCode'] as String,
      workspaceName:     args['workspaceName'] as String,
      logoSvgString:     args['logoSvgString'] as String? ?? '',
    );

List<Map<String, dynamic>> _castList(List raw) =>
    raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

// ── Service ───────────────────────────────────────────────────────────────────

class PdfDocumentService {
  Future<Uint8List> generateToolOutputPdf({
    required String decisionTitle,
    required String toolName,
    required String toolKey,
    required String toolOutput,
    required Map<String, dynamic> outputs,
    required Map<String, dynamic> inputs,
    required List<Map<String, dynamic>> projections,
    required List<Map<String, dynamic>> projectionColumns,
    required String currencyCode,
    required String workspaceName,
    String logoSvgString = '',
  }) async {
    final pdf   = pw.Document();
    final now   = DateTime.now();
    final label = DateFormat('d MMMM yyyy').format(now);

    // ── 1. Cover page ─────────────────────────────────────────────────────────
    pdf.addPage(_coverPage(
      decisionTitle: decisionTitle,
      toolName:      toolName,
      workspaceName: workspaceName,
      dateLabel:     label,
      logoSvgString: logoSvgString,
    ));

    // ── 2–5. Multi-page content ───────────────────────────────────────────────
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin:     const pw.EdgeInsets.fromLTRB(48, 40, 48, 48),
      header: (ctx) => _pageHeader(ctx, decisionTitle, label, logoSvgString),
      footer: (ctx) => _pageFooter(ctx, label),
      build: (ctx) => [
        // ── Section 2: Summary metrics ─────────────────────────────────────
        if (outputs.isNotEmpty) ...[
          ..._summaryMetricsSection(outputs, currencyCode),
          pw.SizedBox(height: 24),
        ],

        // ── Section 3: Chart ───────────────────────────────────────────────
        if (projections.isNotEmpty) ...[
          _sectionHeading('Analysis Chart'),
          pw.SizedBox(height: 10),
          _buildChart(toolKey, projections),
          pw.SizedBox(height: 24),
        ],

        // ── Section 3b: Narrative ──────────────────────────────────────────
        if (toolOutput.isNotEmpty) ...[
          for (final section in _parseSections(toolOutput)) ...[
            pw.SizedBox(height: 8),
            _buildSection(section),
          ],
          if (_parseSections(toolOutput).isEmpty) ...[
            _sectionHeading('Analysis Output'),
            pw.SizedBox(height: 8),
            _bodyText(toolOutput),
            pw.Divider(color: _border, thickness: 0.5),
          ],
          pw.SizedBox(height: 24),
        ],

        // ── Section 4: Projections table ───────────────────────────────────
        if (projections.isNotEmpty && projectionColumns.isNotEmpty) ...[
          _sectionHeading('Data Projections'),
          pw.SizedBox(height: 10),
          _projectionsTable(projectionColumns, projections, currencyCode),
          pw.SizedBox(height: 24),
        ],

        // ── Section 5: Inputs audit trail ──────────────────────────────────
        if (inputs.isNotEmpty) ...[
          _sectionHeading('Input Parameters'),
          pw.SizedBox(height: 10),
          _inputsTable(inputs),
          pw.SizedBox(height: 24),
        ],

        // ── Section 6: Methodology & disclaimer ───────────────────────────
        _sectionHeading('Methodology & Disclaimer'),
        pw.SizedBox(height: 8),
        _methodologyBlock(toolName),
      ],
    ));

    return pdf.save();
  }

  // ── Cover page ──────────────────────────────────────────────────────────────

  pw.Page _coverPage({
    required String decisionTitle,
    required String toolName,
    required String workspaceName,
    required String dateLabel,
    required String logoSvgString,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => pw.Stack(
        children: [
          // Dark side panel
          pw.Positioned(
            top: 0, left: 0, bottom: 0,
            child: pw.Container(width: 8, color: _teal),
          ),
          // Top accent bar
          pw.Positioned(
            top: 0, left: 0, right: 0,
            child: pw.Container(height: 4, color: _teal),
          ),
          // Content
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(56, 56, 48, 48),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Brand mark
                if (logoSvgString.isNotEmpty)
                  pw.SvgImage(svg: logoSvgString, width: 40, height: 40)
                else
                  pw.Container(
                    width: 40, height: 40,
                    decoration: pw.BoxDecoration(
                      color: _teal,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Center(
                      child: pw.Text('R',
                        style: pw.TextStyle(
                          color: _white, fontSize: 22,
                          fontWeight: pw.FontWeight.bold)),
                    ),
                  ),
                pw.SizedBox(height: 8),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'REFLECT',
                      style: pw.TextStyle(
                        color: _darkBg,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'DECISION INTELLIGENCE OS',
                      style: pw.TextStyle(
                        color: _teal,
                        fontSize: 7,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 72),

                // Tool name badge
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: _teal,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    toolName,
                    style: pw.TextStyle(
                      color: _white,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 16),

                // Decision title
                pw.Text(
                  decisionTitle,
                  style: pw.TextStyle(
                    color: _textDark,
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    lineSpacing: 4,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'Tool Analysis Report',
                  style: pw.TextStyle(color: _textMuted, fontSize: 13),
                ),

                pw.Spacer(),

                // Metadata row
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: _rowAlt,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: const pw.Border(
                      top: pw.BorderSide(color: _border, width: 0.5),
                      bottom: pw.BorderSide(color: _border, width: 0.5),
                      left: pw.BorderSide(color: _border, width: 0.5),
                      right: pw.BorderSide(color: _border, width: 0.5),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _metaBox('Generated', dateLabel),
                      _metaBox('Workspace', workspaceName),
                      _metaBox('Platform', 'Reflect OS'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _metaBox(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(color: _textMuted, fontSize: 9)),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: _textDark, fontSize: 10, fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ── Page header / footer ────────────────────────────────────────────────────

  pw.Widget _pageHeader(
      pw.Context ctx, String title, String dateLabel, String logoSvgString) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(height: 2, color: _teal),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(
              children: [
                if (logoSvgString.isNotEmpty) ...[
                  pw.SvgImage(svg: logoSvgString, width: 16, height: 16),
                  pw.SizedBox(width: 5),
                ],
                pw.Text('REFLECT OS',
                    style: pw.TextStyle(
                        color: _teal, fontSize: 9, letterSpacing: 1.5,
                        fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.Text(
              title.length > 60 ? '${title.substring(0, 57)}…' : title,
              style: pw.TextStyle(color: _textMuted, fontSize: 9),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  pw.Widget _pageFooter(pw.Context ctx, String dateLabel) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Divider(color: _border, thickness: 0.5),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Confidential — Generated $dateLabel',
                style: pw.TextStyle(color: _textMuted, fontSize: 8)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(color: _textMuted, fontSize: 8)),
          ],
        ),
      ],
    );
  }

  // ── Section 2: Summary metrics ──────────────────────────────────────────────

  List<pw.Widget> _summaryMetricsSection(
      Map<String, dynamic> outputs, String currencyCode) {
    final numeric = outputs.entries
        .where((e) => e.value is num && (e.value as num) != 0)
        .toList();
    final nonNumeric = outputs.entries
        .where((e) => e.value is! num)
        .toList();

    if (numeric.isEmpty && nonNumeric.isEmpty) return [];

    final maxVal = numeric.isEmpty
        ? 1.0
        : numeric
            .map((e) => (e.value as num).abs().toDouble())
            .reduce(math.max);

    // Hero: first numeric entry
    final heroEntry = numeric.isNotEmpty ? numeric.first : null;
    final restNumeric = numeric.length > 1 ? numeric.sublist(1) : <MapEntry<String, dynamic>>[];

    return [
      _sectionHeading('Key Results'),
      pw.SizedBox(height: 10),

      // Hero metric
      if (heroEntry != null) ...[
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFE6FAFB),
            borderRadius: pw.BorderRadius.circular(8),
            border: const pw.Border(
              top: pw.BorderSide(color: _teal, width: 1.5),
              bottom: pw.BorderSide(color: _border, width: 0.5),
              left: pw.BorderSide(color: _border, width: 0.5),
              right: pw.BorderSide(color: _border, width: 0.5),
            ),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _humanLabel(heroEntry.key),
                      style: pw.TextStyle(color: _textMuted, fontSize: 10),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _formatNum(heroEntry.value, currencyCode),
                      style: pw.TextStyle(
                        color: _teal,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
      ],

      // 2-column metric grid
      if (restNumeric.isNotEmpty) ...[
        pw.Wrap(
          spacing: 8,
          runSpacing: 8,
          children: restNumeric.take(6).map((e) {
            final isPositive = (e.value as num) >= 0;
            return pw.Container(
              width: 230,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _rowAlt,
                borderRadius: pw.BorderRadius.circular(6),
                border: const pw.Border(
                  top: pw.BorderSide(color: _border, width: 0.5),
                  bottom: pw.BorderSide(color: _border, width: 0.5),
                  left: pw.BorderSide(color: _border, width: 0.5),
                  right: pw.BorderSide(color: _border, width: 0.5),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(_humanLabel(e.key),
                      style: pw.TextStyle(color: _textMuted, fontSize: 9)),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    _formatNum(e.value, currencyCode),
                    style: pw.TextStyle(
                      color: isPositive ? _green : _red,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        pw.SizedBox(height: 10),
      ],

      // Bar chart for numeric values
      if (numeric.isNotEmpty && maxVal > 0) ...[
        pw.SizedBox(height: 4),
        for (final e in numeric.take(8)) ...[
          _metricBar(e.key, e.value, maxVal, currencyCode),
          pw.SizedBox(height: 5),
        ],
      ],

      // Non-numeric outputs
      if (nonNumeric.isNotEmpty) ...[
        pw.SizedBox(height: 8),
        for (final e in nonNumeric.take(6)) ...[
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 140,
                child: pw.Text(_humanLabel(e.key),
                    style: pw.TextStyle(color: _textMuted, fontSize: 9)),
              ),
              pw.Expanded(
                child: pw.Text(
                  e.value?.toString() ?? '—',
                  style: pw.TextStyle(color: _textDark, fontSize: 9),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
        ],
      ],
    ];
  }

  pw.Widget _metricBar(
      String key, dynamic value, double maxVal, String currency) {
    final v = (value as num).abs().toDouble();
    final fraction = maxVal > 0 ? (v / maxVal).clamp(0.0, 1.0) : 0.0;
    final isNeg = v.isNegative;
    const barArea = 280.0;

    return pw.Row(
      children: [
        pw.SizedBox(
          width: 130,
          child: pw.Text(_humanLabel(key),
              style: pw.TextStyle(color: _textMuted, fontSize: 9),
              maxLines: 1),
        ),
        pw.SizedBox(
          width: barArea,
          child: pw.Stack(
            children: [
              pw.Container(
                height: 8,
                decoration: pw.BoxDecoration(
                  color: _border,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
              ),
              pw.Container(
                width: barArea * fraction,
                height: 8,
                decoration: pw.BoxDecoration(
                  color: isNeg ? _red : _teal,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          _formatNum(value, currency),
          style: pw.TextStyle(
            color: isNeg ? _red : _textDark,
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ── Section 3: Charts via pw.CustomPaint ────────────────────────────────────

  pw.Widget _buildChart(
      String toolKey, List<Map<String, dynamic>> projections) {
    const w = 498.0;
    const h = 200.0;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: const pw.Border(
          top: pw.BorderSide(color: _border, width: 0.5),
          bottom: pw.BorderSide(color: _border, width: 0.5),
          left: pw.BorderSide(color: _border, width: 0.5),
          right: pw.BorderSide(color: _border, width: 0.5),
        ),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: switch (toolKey) {
        'sensitivity_analysis_v2' => _tornadoChart(projections, w, h),
        'risk_matrix_v2'          => _heatmapChart(projections, w, h),
        'stakeholder_alignment_v2' => _stakeholderMatrix(projections, w, h),
        'scenario_builder_v2' ||
        'reference_class_forecast_v2' ||
        'ab_test_calculator_v2' ||
        'delivery_confidence_v2'  => _fanBandChart(projections, w, h),
        'cost_of_inaction_v2' ||
        'attrition_risk_v2' ||
        'base_rate_lookup_v2' ||
        'outcome_metric_builder_v2' => _barChart(projections, w, h),
        _                           => _lineChart(projections, w, h),
      },
    );
  }

  // Line chart painter
  pw.Widget _lineChart(
      List<Map<String, dynamic>> rows, double w, double h) {
    final numericKeys = rows.isNotEmpty
        ? rows.first.keys
            .where((k) => !_isLabelKey(k) && rows.first[k] is num)
            .toList()
        : <String>[];
    if (numericKeys.isEmpty) return pw.SizedBox(height: h);

    final seriesColours = [_teal, _green, _amber, _red,
        PdfColor.fromInt(0xFF6366F1), PdfColor.fromInt(0xFF8B5CF6)];

    // Find y range
    double minY = 0, maxY = 0;
    for (final row in rows) {
      for (final key in numericKeys) {
        final v = (row[key] as num?)?.toDouble() ?? 0;
        if (v < minY) minY = v;
        if (v > maxY) maxY = v;
      }
    }
    if (maxY == minY) maxY = minY + 1;

    final xStep = rows.length > 1 ? w / (rows.length - 1) : w;
    final yRange = maxY - minY;

    return pw.CustomPaint(
      size: PdfPoint(w, h),
      painter: (canvas, size) {
        // Grid lines
        canvas.setColor(_border);
        canvas.setLineWidth(0.3);
        for (var i = 0; i <= 4; i++) {
          final y = h * i / 4;
          canvas.moveTo(0, y);
          canvas.lineTo(w, y);
          canvas.strokePath();
        }

        // Series lines
        for (var si = 0; si < numericKeys.length && si < seriesColours.length; si++) {
          final key = numericKeys[si];
          canvas.setColor(seriesColours[si]);
          canvas.setLineWidth(1.5);
          bool first = true;
          for (var i = 0; i < rows.length; i++) {
            final v = (rows[i][key] as num?)?.toDouble() ?? 0;
            final x = i * xStep;
            final y = ((v - minY) / yRange) * h;
            if (first) {
              canvas.moveTo(x, y);
              first = false;
            } else {
              canvas.lineTo(x, y);
            }
          }
          canvas.strokePath();

          // Dots
          for (var i = 0; i < rows.length; i++) {
            final v = (rows[i][key] as num?)?.toDouble() ?? 0;
            final x = i * xStep;
            final y = ((v - minY) / yRange) * h;
            canvas.setColor(seriesColours[si]);
            canvas.drawEllipse(x, y, 2.5, 2.5);
            canvas.fillPath();
          }
        }
      },
    );
  }

  // Fan/band chart painter
  pw.Widget _fanBandChart(
      List<Map<String, dynamic>> rows, double w, double h) {
    // Try to find upper, base, lower keys
    final upper = _findKey(rows, ['best_case', 'optimistic', 'upper']);
    final base  = _findKey(rows, ['expected_case', 'base_forecast', 'base', 'expected']);
    final lower = _findKey(rows, ['worst_case', 'pessimistic', 'lower']);

    if (base == null) return _lineChart(rows, w, h);

    double minY = double.infinity, maxY = double.negativeInfinity;
    for (final row in rows) {
      for (final k in [upper, base, lower]) {
        if (k == null) continue;
        final v = (row[k] as num?)?.toDouble() ?? 0;
        if (v < minY) minY = v;
        if (v > maxY) maxY = v;
      }
    }
    if (minY == maxY) { minY -= 1; maxY += 1; }
    final yRange = maxY - minY;
    final xStep = rows.length > 1 ? w / (rows.length - 1) : w;

    List<PdfPoint> pts(String? key) {
      if (key == null) return [];
      return [
        for (var i = 0; i < rows.length; i++)
          PdfPoint(
            i * xStep,
            (((rows[i][key] as num?)?.toDouble() ?? 0) - minY) / yRange * h,
          ),
      ];
    }

    final basePts  = pts(base);
    final upperPts = pts(upper);
    final lowerPts = pts(lower);

    return pw.CustomPaint(
      size: PdfPoint(w, h),
      painter: (canvas, size) {
        // Grid
        canvas.setColor(_border);
        canvas.setLineWidth(0.3);
        for (var i = 0; i <= 4; i++) {
          canvas.moveTo(0, h * i / 4);
          canvas.lineTo(w, h * i / 4);
          canvas.strokePath();
        }

        // Band fill (upper→lower polygon)
        if (upperPts.isNotEmpty && lowerPts.isNotEmpty) {
          canvas.setColor(PdfColor.fromInt(0x2619CBD6)); // teal @ 15%
          canvas.moveTo(upperPts.first.x, upperPts.first.y);
          for (final p in upperPts.skip(1)) { canvas.lineTo(p.x, p.y); }
          for (final p in lowerPts.reversed) { canvas.lineTo(p.x, p.y); }
          canvas.closePath();
          canvas.fillPath();
        }

        // Upper / lower dashed lines
        for (final (pts2, col) in [(upperPts, _green), (lowerPts, _red)]) {
          if (pts2.isEmpty) continue;
          canvas.setColor(col);
          canvas.setLineWidth(0.8);
          canvas.moveTo(pts2.first.x, pts2.first.y);
          for (final p in pts2.skip(1)) { canvas.lineTo(p.x, p.y); }
          canvas.strokePath();
        }

        // Base line (solid teal)
        if (basePts.isNotEmpty) {
          canvas.setColor(_teal);
          canvas.setLineWidth(1.8);
          canvas.moveTo(basePts.first.x, basePts.first.y);
          for (final p in basePts.skip(1)) { canvas.lineTo(p.x, p.y); }
          canvas.strokePath();
        }
      },
    );
  }

  // Vertical bar chart painter
  pw.Widget _barChart(
      List<Map<String, dynamic>> rows, double w, double h) {
    final key = rows.isNotEmpty
        ? rows.first.keys.firstWhere(
            (k) => !_isLabelKey(k) && rows.first[k] is num,
            orElse: () => '')
        : '';
    if (key.isEmpty) return pw.SizedBox(height: h);

    double maxY = 0;
    for (final row in rows) {
      final v = (row[key] as num?)?.toDouble() ?? 0;
      if (v.abs() > maxY) maxY = v.abs();
    }
    if (maxY == 0) maxY = 1;

    final barW = (w / rows.length) * 0.6;
    final gap   = w / rows.length;

    return pw.CustomPaint(
      size: PdfPoint(w, h),
      painter: (canvas, size) {
        // Grid
        canvas.setColor(_border);
        canvas.setLineWidth(0.3);
        for (var i = 0; i <= 4; i++) {
          canvas.moveTo(0, h * i / 4);
          canvas.lineTo(w, h * i / 4);
          canvas.strokePath();
        }
        // Bars
        for (var i = 0; i < rows.length; i++) {
          final v = (rows[i][key] as num?)?.toDouble() ?? 0;
          final barH = (v.abs() / maxY) * h * 0.9;
          final x = i * gap + (gap - barW) / 2;
          final color = v >= 0 ? _teal : _red;
          canvas.setColor(color);
          canvas.drawRect(x, 0, barW, barH);
          canvas.fillPath();
        }
      },
    );
  }

  // Tornado / horizontal bar chart
  pw.Widget _tornadoChart(
      List<Map<String, dynamic>> rows, double w, double h) {
    if (rows.isEmpty) return pw.SizedBox(height: h);

    // Each row has: label + numeric value (positive = increases outcome, negative = decreases)
    final valueKey = rows.first.keys.firstWhere(
        (k) => !_isLabelKey(k) && rows.first[k] is num,
        orElse: () => '');
    if (valueKey.isEmpty) return _barChart(rows, w, h);

    double maxAbs = 0;
    for (final row in rows) {
      final v = (row[valueKey] as num?)?.toDouble() ?? 0;
      if (v.abs() > maxAbs) maxAbs = v.abs();
    }
    if (maxAbs == 0) maxAbs = 1;

    const labelW = 120.0;
    final barArea = w - labelW - 8;
    final center  = labelW + barArea / 2;
    final barH    = math.min(14.0, (h - 8) / rows.length - 3);
    final gap     = (h - rows.length * barH) / (rows.length + 1);

    return pw.CustomPaint(
      size: PdfPoint(w, h),
      painter: (canvas, size) {
        // Center line
        canvas.setColor(_border);
        canvas.setLineWidth(0.5);
        canvas.moveTo(center, 0);
        canvas.lineTo(center, h);
        canvas.strokePath();

        for (var i = 0; i < rows.length; i++) {
          final v = (rows[i][valueKey] as num?)?.toDouble() ?? 0;
          final fraction = (v.abs() / maxAbs).clamp(0.0, 1.0);
          final barLen   = fraction * (barArea / 2 - 4);
          final y        = h - (gap + i * (barH + gap)) - barH; // top of bar (y up)
          final color    = v >= 0 ? _green : _red;

          canvas.setColor(color);
          if (v >= 0) {
            canvas.drawRect(center, y, barLen, barH);
          } else {
            canvas.drawRect(center - barLen, y, barLen, barH);
          }
          canvas.fillPath();
        }
      },
    );
  }

  // Risk heatmap (5×5 grid)
  pw.Widget _heatmapChart(
      List<Map<String, dynamic>> rows, double w, double h) {
    final cellW = w / 5;
    final cellH = h / 5;

    // Parse rows: expect probability 1-5, impact 1-5
    final probKey   = _findKey(rows, ['probability', 'likelihood', 'prob']);
    final impactKey = _findKey(rows, ['impact', 'severity', 'consequence']);

    return pw.CustomPaint(
      size: PdfPoint(w, h),
      painter: (canvas, size) {
        // Background heatmap grid (color = prob * impact)
        for (var px = 0; px < 5; px++) {
          for (var ix = 0; ix < 5; ix++) {
            final score = (px + 1) * (ix + 1); // 1–25
            final alpha = score / 25.0;
            final color = _heatColor(alpha);
            canvas.setColor(color);
            canvas.drawRect(
              px * cellW, ix * cellH, cellW - 1, cellH - 1);
            canvas.fillPath();
          }
        }

        // Grid borders
        canvas.setColor(_border);
        canvas.setLineWidth(0.5);
        for (var i = 0; i <= 5; i++) {
          canvas.moveTo(i * cellW, 0);
          canvas.lineTo(i * cellW, h);
          canvas.strokePath();
          canvas.moveTo(0, i * cellH);
          canvas.lineTo(w, i * cellH);
          canvas.strokePath();
        }

        // Plot risks as circles
        if (probKey != null && impactKey != null) {
          for (final row in rows) {
            final p = ((row[probKey] as num?)?.toInt() ?? 1).clamp(1, 5);
            final i = ((row[impactKey] as num?)?.toInt() ?? 1).clamp(1, 5);
            final cx = (p - 0.5) * cellW;
            final cy = (i - 0.5) * cellH;
            canvas.setColor(_darkBg);
            canvas.drawEllipse(cx, cy, cellW * 0.28, cellH * 0.28);
            canvas.fillPath();
          }
        }
      },
    );
  }

  // Stakeholder matrix (2D scatter: influence vs support)
  pw.Widget _stakeholderMatrix(
      List<Map<String, dynamic>> rows, double w, double h) {
    final xKey = _findKey(rows, ['influence', 'power', 'x_value']);
    final yKey = _findKey(rows, ['support', 'alignment', 'y_value', 'interest']);

    if (xKey == null || yKey == null) return _barChart(rows, w, h);

    double xMax = 10, yMax = 10;
    for (final row in rows) {
      final x = (row[xKey] as num?)?.toDouble() ?? 0;
      final y = (row[yKey] as num?)?.toDouble() ?? 0;
      if (x > xMax) xMax = x;
      if (y > yMax) yMax = y;
    }

    final quadrantColours = [
      PdfColor.fromInt(0x1A2EA073), // manage closely (top-right) - green
      PdfColor.fromInt(0x1ADD3433), // monitor (bottom-right) - red
      PdfColor.fromInt(0x1AD97D24), // keep informed (top-left) - amber
      PdfColor.fromInt(0x1A94A3B8), // minimal effort (bottom-left) - grey
    ];

    return pw.CustomPaint(
      size: PdfPoint(w, h),
      painter: (canvas, size) {
        // Quadrant backgrounds
        canvas.setColor(quadrantColours[0]);
        canvas.drawRect(w / 2, h / 2, w / 2, h / 2);
        canvas.fillPath();
        canvas.setColor(quadrantColours[1]);
        canvas.drawRect(w / 2, 0, w / 2, h / 2);
        canvas.fillPath();
        canvas.setColor(quadrantColours[2]);
        canvas.drawRect(0, h / 2, w / 2, h / 2);
        canvas.fillPath();
        canvas.setColor(quadrantColours[3]);
        canvas.drawRect(0, 0, w / 2, h / 2);
        canvas.fillPath();

        // Axis lines
        canvas.setColor(_border);
        canvas.setLineWidth(0.5);
        canvas.moveTo(w / 2, 0); canvas.lineTo(w / 2, h); canvas.strokePath();
        canvas.moveTo(0, h / 2); canvas.lineTo(w, h / 2); canvas.strokePath();

        // Plot stakeholders
        for (final row in rows) {
          final xv = (row[xKey] as num?)?.toDouble() ?? 0;
          final yv = (row[yKey] as num?)?.toDouble() ?? 0;
          final cx = (xv / xMax) * w;
          final cy = (yv / yMax) * h;
          canvas.setColor(_teal);
          canvas.drawEllipse(cx, cy, 5, 5);
          canvas.fillPath();
          canvas.setColor(_white);
          canvas.drawEllipse(cx, cy, 2, 2);
          canvas.fillPath();
        }
      },
    );
  }

  PdfColor _heatColor(double alpha) {
    if (alpha < 0.33) return PdfColor.fromInt(0xFF2EA073); // green
    if (alpha < 0.66) return PdfColor.fromInt(0xFFD97D24); // amber
    return PdfColor.fromInt(0xFFDC4444);                   // red
  }

  // ── Section 4: Projections table ────────────────────────────────────────────

  pw.Widget _projectionsTable(
      List<Map<String, dynamic>> columns,
      List<Map<String, dynamic>> rows,
      String currency) {
    if (columns.isEmpty || rows.isEmpty) return pw.SizedBox.shrink();

    final headers = columns.map((c) => c['label'] as String? ?? '').toList();
    final colIds  = columns.map((c) => c['id'] as String).toList();
    final colW    = (498.0 - 16) / columns.length;

    pw.Widget cell(String text, {bool isHeader = false, bool isAlt = false}) {
      return pw.Container(
        width: colW,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        color: isHeader
            ? PdfColor.fromInt(0xFFE6FAFB)
            : isAlt ? _rowAlt : _white,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            color: isHeader ? _teal : _textDark,
            fontSize: 8.5,
            fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
          maxLines: 1,
        ),
      );
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: const pw.Border(
          top: pw.BorderSide(color: _border, width: 0.5),
          bottom: pw.BorderSide(color: _border, width: 0.5),
          left: pw.BorderSide(color: _border, width: 0.5),
          right: pw.BorderSide(color: _border, width: 0.5),
        ),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 6,
        verticalRadius: 6,
        child: pw.Column(
          children: [
            // Header row
            pw.Row(children: headers.map((h) => cell(h, isHeader: true)).toList()),
            // Data rows
            for (var i = 0; i < rows.length; i++) ...[
              pw.Container(height: 0.5, color: _border),
              pw.Row(
                children: colIds.map((id) {
                  final col = columns.firstWhere(
                      (c) => c['id'] == id, orElse: () => {});
                  final type = col['type'] as String?;
                  final raw  = rows[i][id];
                  return cell(_formatValue(raw, type, currency),
                      isAlt: i.isOdd);
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Section 5: Inputs audit trail ───────────────────────────────────────────

  pw.Widget _inputsTable(Map<String, dynamic> inputs) {
    final entries = inputs.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .toList();
    if (entries.isEmpty) return pw.SizedBox.shrink();

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: const pw.Border(
          top: pw.BorderSide(color: _border, width: 0.5),
          bottom: pw.BorderSide(color: _border, width: 0.5),
          left: pw.BorderSide(color: _border, width: 0.5),
          right: pw.BorderSide(color: _border, width: 0.5),
        ),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 6,
        verticalRadius: 6,
        child: pw.Column(
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) pw.Container(height: 0.5, color: _border),
              pw.Container(
                color: i.isOdd ? _rowAlt : _white,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                child: pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 170,
                      child: pw.Text(
                        _humanLabel(entries[i].key),
                        style: pw.TextStyle(color: _textMuted, fontSize: 9),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        entries[i].value?.toString() ?? '—',
                        style: pw.TextStyle(color: _textDark, fontSize: 9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Section 6: Methodology & disclaimer ─────────────────────────────────────

  pw.Widget _methodologyBlock(String toolName) {
    const disclaimer =
        'This report has been generated by Reflect OS, a decision intelligence '
        'platform. The calculations, projections and analysis contained herein are '
        'based solely on the input parameters provided and standard financial / '
        'strategic modelling methodologies. They are intended to support structured '
        'decision-making and should not be construed as financial advice, legal '
        'opinion or a guarantee of future results. All projections are inherently '
        'uncertain; actual outcomes may differ materially from those illustrated. '
        'The decision-maker retains full responsibility for any action taken. '
        'Reflect OS and its licensors accept no liability for decisions made in '
        'reliance on this output.';

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _rowAlt,
        borderRadius: pw.BorderRadius.circular(6),
        border: const pw.Border(
          top: pw.BorderSide(color: _border, width: 0.5),
          bottom: pw.BorderSide(color: _border, width: 0.5),
          left: pw.BorderSide(color: _border, width: 0.5),
          right: pw.BorderSide(color: _border, width: 0.5),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'About $toolName',
            style: pw.TextStyle(
              color: _textDark,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'This analysis was produced using the $toolName model within Reflect OS. '
            'The tool applies structured quantitative methodology to transform your '
            'input parameters into projected outcomes across the defined time horizon. '
            'Sensitivity ranges reflect parametric variance, not probabilistic '
            'simulation unless explicitly stated.',
            style: pw.TextStyle(color: _textDark, fontSize: 9, lineSpacing: 2),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Disclaimer',
            style: pw.TextStyle(
              color: _textDark,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            disclaimer,
            style: pw.TextStyle(
                color: _textMuted, fontSize: 8.5, lineSpacing: 2),
            textAlign: pw.TextAlign.justify,
          ),
        ],
      ),
    );
  }

  // ── Section parser (narrative) ───────────────────────────────────────────────

  List<_Section> _parseSections(String text) {
    final sections = <_Section>[];
    final lines = text.split('\n');
    String? heading;
    final bullets = <String>[];
    final body = StringBuffer();

    void flush() {
      if (heading != null || body.isNotEmpty) {
        sections.add(_Section(
          heading: heading ?? '',
          body: body.toString().trim(),
          bullets: List<String>.from(bullets),
        ));
        heading = null;
        bullets.clear();
        body.clear();
      }
    }

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('## ') || line.startsWith('# ')) {
        flush();
        heading = line.replaceAll(RegExp(r'^#+\s*'), '');
      } else if (line.endsWith(':') && line.length < 60 && !line.startsWith('-')) {
        flush();
        heading = line.substring(0, line.length - 1);
      } else if (line.startsWith('- ') || line.startsWith('• ') ||
                 line.startsWith('* ')) {
        bullets.add(line.substring(2).trim());
      } else {
        if (body.isNotEmpty) body.write(' ');
        body.write(line);
      }
    }
    flush();
    return sections;
  }

  pw.Widget _buildSection(_Section section) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (section.heading.isNotEmpty) ...[
          _sectionHeading(section.heading),
          pw.SizedBox(height: 6),
        ],
        if (section.body.isNotEmpty) ...[
          _bodyText(section.body),
          pw.SizedBox(height: 8),
        ],
        for (final bullet in section.bullets) ...[
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 5,
                height: 5,
                margin: const pw.EdgeInsets.only(top: 3.5, right: 8),
                decoration: const pw.BoxDecoration(
                    color: _teal, shape: pw.BoxShape.circle),
              ),
              pw.Expanded(
                child: pw.Text(bullet,
                    style: pw.TextStyle(color: _textDark, fontSize: 10)),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
        ],
        pw.Divider(color: _border, thickness: 0.5),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  pw.Widget _sectionHeading(String text) {
    return pw.Text(
      text.toUpperCase(),
      style: pw.TextStyle(
        color: _teal,
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }

  pw.Widget _bodyText(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(color: _textDark, fontSize: 10, lineSpacing: 2),
      textAlign: pw.TextAlign.justify,
    );
  }

  String _humanLabel(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _formatNum(dynamic v, [String currency = 'GBP']) {
    if (v is! num) return v?.toString() ?? '—';
    final d = v.toDouble();
    if (d.abs() >= 1000000) return '${(d / 1000000).toStringAsFixed(1)}M';
    if (d.abs() >= 1000) return '${(d / 1000).toStringAsFixed(0)}k';
    return d.toStringAsFixed(d == d.truncateToDouble() ? 0 : 2);
  }

  String _formatValue(dynamic v, String? type, [String currency = 'GBP']) {
    if (v == null) return '—';
    if (type == 'currency') return '$currency ${_formatNum(v, currency)}';
    if (type == 'percent') return '${_formatNum(v, currency)}%';
    if (v is num) return _formatNum(v, currency);
    return v.toString();
  }

  bool _isLabelKey(String key) {
    const labelKeys = {'year', 'month', 'week', 'period', 'label',
        'name', 'category', 'item', 'factor'};
    return labelKeys.contains(key.toLowerCase());
  }

  String? _findKey(List<Map<String, dynamic>> rows, List<String> candidates) {
    if (rows.isEmpty) return null;
    for (final c in candidates) {
      if (rows.first.containsKey(c)) return c;
    }
    return null;
  }
}

class _Section {
  const _Section({
    required this.heading,
    required this.body,
    required this.bullets,
  });
  final String heading;
  final String body;
  final List<String> bullets;
}
