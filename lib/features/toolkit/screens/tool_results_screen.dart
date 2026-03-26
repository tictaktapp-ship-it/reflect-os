import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/core/utils/pdf_downloader.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';
import 'package:reflect_os/features/evidence/providers/evidence_provider.dart';
import 'package:reflect_os/features/risk/providers/risk_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/toolkit_providers.dart';
import '../data/models/tool_definition.dart';
import '../data/models/tool_run.dart';
import '../data/toolkit_repository.dart';
import '../engine/calculator_engine.dart';
import '../services/pdf_document_service.dart';
import 'package:reflect_os/core/theme/app_radius.dart';

/// Displays computed results for a tool run.
///
/// Receives via [GoRouterState.extra] a Dart record:
/// ```
/// ({ToolCalculationResult result, ToolRun run, ToolDefinition tool, String? decisionId})
/// ```
class ToolResultsScreen extends ConsumerStatefulWidget {
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
  ConsumerState<ToolResultsScreen> createState() => _ToolResultsScreenState();
}

class _ToolResultsScreenState extends ConsumerState<ToolResultsScreen> {
  late final TextEditingController _descCtrl =
      TextEditingController(text: widget.result.narrative);
  bool _attachAudit    = false;
  bool _isInjecting    = false;
  bool _isDownloading  = false;
  bool _isSaving       = false;
  bool _isSharingChat  = false;
  Uint8List? _pdfBytes;
  String? _storagePath;          // path used when uploading to generated-documents
  String? _attachedDecisionId;
  String? _generatedDocumentId;

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
      final repo = const ToolkitRepository();
      await repo.approveAndInjectToolOutput(
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

      // If the run was created without a decision context (e.g. from the
      // standalone toolkit), link it to this decision now so it appears in
      // the detail screen's Tool Kit section.
      await repo.linkRunToDecision(
        toolRunId:  widget.run.id,
        decisionId: decisionId,
      );

      if (!mounted) return;
      // Invalidate cached providers so the detail screen reloads fresh data.
      ref.invalidate(decisionDetailProvider(decisionId));
      ref.invalidate(projectedOutcomeProvider(decisionId));
      ref.invalidate(decisionToolRunsProvider(decisionId));
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

  // ── PDF download ──────────────────────────────────────────────────────────

  Future<void> _downloadPdf() async {
    setState(() => _isDownloading = true);
    try {
      // Generate PDF bytes (or reuse cached bytes).
      final decisionId = widget.decisionId ?? widget.run.decisionId;
      String decisionTitle = 'Decision Analysis';
      String workspaceName = '';
      if (decisionId != null) {
        final detail =
            await ref.read(decisionDetailProvider(decisionId).future);
        decisionTitle = detail?.title ?? decisionTitle;
      }
      workspaceName =
          await ref.read(workspaceNameProvider.future) ?? '';

      // Load brand SVG on main isolate before spawning compute().
      String logoSvgString = '';
      try {
        final svgData = await rootBundle.load('assets/branding/icon.svg');
        logoSvgString = utf8.decode(svgData.buffer.asUint8List());
      } catch (_) {}

      Uint8List bytes = _pdfBytes ??
          await compute(generatePdfBackground, {
            'decisionTitle':     decisionTitle,
            'toolName':          widget.tool.name,
            'toolKey':           widget.tool.key,
            'toolOutput':        widget.result.narrative,
            'outputs':           widget.result.summaryOutputs,
            'inputs':            widget.run.inputsJsonb,
            'projections':       widget.result.annualProjections,
            'projectionColumns': widget.tool.annualProjectionColumns,
            'currencyCode':      widget.run.currencyCode,
            'workspaceName':     workspaceName,
            'logoSvgString':     logoSvgString,
          });
      _pdfBytes = bytes;

      final fileName =
          'tool_output_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (kIsWeb) {
        // On web: upload, get signed URL, open in new tab.
        final workspaceId =
            ref.read(currentWorkspaceProvider).valueOrNull;
        final userId = supabase.auth.currentUser?.id;
        if (workspaceId != null && userId != null) {
          // User-scoped path so storage ownership is clear.
          final storagePath = decisionId != null
              ? '$userId/decisions/$decisionId/$fileName'
              : '$userId/standalone/$fileName';

          // Upload to storage.
          await supabase.storage
              .from('generated-documents')
              .uploadBinary(
                storagePath,
                bytes,
                fileOptions: const FileOptions(
                  contentType: 'application/pdf',
                  upsert: true,
                ),
              );

          // Track the storage path for use in evidence attachment.
          if (mounted) setState(() => _storagePath = storagePath);

          // Insert / update generated_documents row if we have a decision.
          if (decisionId != null) {
            try {
              final repo = const ToolkitRepository();
              final docId = await repo.insertGeneratedDocument(
                workspaceId: workspaceId,
                userId: userId,
                decisionId: decisionId,
              );
              if (mounted) setState(() => _generatedDocumentId = docId);
              await repo.updateDocumentStoragePath(
                documentId: docId,
                storageBucket: 'generated-documents',
                storagePath: storagePath,
              );
              await repo.linkGeneratedDocumentToRun(
                toolRunId: widget.run.id,
                documentId: docId,
              );
            } catch (_) {
              // Non-fatal: DB row tracking is best-effort.
            }
          }

          // Create signed URL and open in new tab.
          final signedUrl = await supabase.storage
              .from('generated-documents')
              .createSignedUrl(storagePath, 3600);
          if (mounted) {
            await launchUrl(
              Uri.parse(signedUrl),
              mode: LaunchMode.externalApplication,
            );
          }
        }
      } else {
        // On mobile: share/print sheet.
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  // ── Attach to decision ────────────────────────────────────────────────────

  Future<void> _attachToDecision(String decisionId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      // Link the run to the decision (no-op if already linked).
      await supabase
          .from('tool_runs')
          .update({'decision_id': decisionId})
          .eq('id', widget.run.id);

      // Insert evidence_items row if the PDF was uploaded to storage.
      // Must happen AFTER tool_runs is linked so can_read_decision() returns true.
      if (_storagePath != null && _pdfBytes != null) {
        final pdfTitle = widget.tool.pdfTitle;
        final filename = '${pdfTitle}_'
            '${DateFormat('yyyyMMdd').format(widget.run.createdAt)}.pdf';
        try {
          await supabase.from('evidence_items').insert({
            'decision_id':        decisionId,
            'type':               'file',
            'label':              '$pdfTitle — Toolkit Output',
            'storage_bucket':     'generated-documents',
            'storage_path':       _storagePath!,
            'original_filename':  filename,
            'mime_type':          'application/pdf',
            'file_size_bytes':    _pdfBytes!.length,
            'created_by_user_id': userId,
          });
          ref.invalidate(evidenceProvider(decisionId));
        } catch (e) {
          debugPrint('EVIDENCE INSERT ERROR: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Failed to attach evidence: ${e.toString()}'),
              backgroundColor: const Color(0xFFDC4444),
            ));
          }
          return;
        }
      }

      // Update generated_documents with the decision linkage.
      if (_generatedDocumentId != null) {
        await supabase
            .from('generated_documents')
            .update({'subject_entity_id': decisionId})
            .eq('id', _generatedDocumentId!);
      }

      // ── Fix 4: Risk Matrix tool → feed risk assessment ──────────────────────
      if (widget.tool.key == 'risk_matrix_v2') {
        final outputs = widget.run.outputsJsonb;
        final inputs  = widget.run.inputsJsonb;
        final risks   = inputs['risks'] as List? ?? [];

        final criticalCount = (outputs['critical_count'] as num?)?.toInt() ?? 0;
        final highCount     = (outputs['high_count'] as num?)?.toInt() ?? 0;
        final overallLevel  = criticalCount > 0
            ? 'critical'
            : highCount > 0 ? 'high' : 'medium';
        const impactMap = {
          'critical': -3,
          'high':     -2,
          'medium':   -1,
          'low':       0,
        };
        final confidenceImpact = impactMap[overallLevel] ?? 0;

        final existing = await supabase
            .from('risk_assessments')
            .select('id')
            .eq('decision_id', decisionId)
            .isFilter('deleted_at', null)
            .maybeSingle();

        final now = DateTime.now().toUtc().toIso8601String();
        final payload = {
          'methodology':         'toolkit_risk_matrix',
          'manual_risks_jsonb':  {'risks': risks},
          'overall_risk_level':  overallLevel,
          'confidence_impact':   confidenceImpact,
          'output_jsonb':        outputs,
          'approved_at':         now,
          'approved_by_user_id': userId,
          'status':              'approved',
          'provider':            'toolkit',
          'model':               'risk_matrix_v2',
          'updated_at':          now,
        };

        if (existing != null) {
          await supabase
              .from('risk_assessments')
              .update(payload)
              .eq('id', existing['id'] as String);
        } else {
          await supabase.from('risk_assessments').insert({
            ...payload,
            'decision_id':          decisionId,
            'requested_by_user_id': userId,
          });
        }

        ref.invalidate(riskAssessmentProvider(decisionId));
        ref.invalidate(approvedRiskAssessmentProvider(decisionId));
        ref.invalidate(riskConfidenceAdjustmentProvider(decisionId));

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Risk data imported to decision. Confidence score updated.'),
              backgroundColor: Color(0xFFD97D24),
            ));
          }
        });
      }

      // ── Fix 4: Scenario Builder → prefill projected outcome ─────────────────
      if (widget.tool.key == 'scenario_builder_v2') {
        final outputs = widget.run.outputsJsonb;
        final decisionRow = await supabase
            .from('decisions')
            .select('projected_outcome_encrypted')
            .eq('id', decisionId)
            .single();

        if (decisionRow['projected_outcome_encrypted'] == null) {
          final ev      = outputs['expected_value_yr1'];
          final evTotal = outputs['expected_value_total'];
          if (ev != null) {
            await supabase.from('decisions').update({
              'projected_outcome_encrypted':
                  'Probability-weighted EV: ${_fmtCurrency((ev as num).toDouble())} '
                  '(Year 1) / ${_fmtCurrency((evTotal as num?)?.toDouble() ?? 0)} (total). '
                  'Generated from Scenario Builder toolkit.',
            }).eq('id', decisionId);
          }
        }
      }

      if (!mounted) return;
      setState(() => _attachedDecisionId = decisionId);

      // Invalidate decision-related providers.
      ref.invalidate(decisionToolRunsProvider(decisionId));

      final detailPath =
          Routes.decisionsDetail.replaceFirst(':id', decisionId);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Expanded(child: Text('Attached to decision. View in Evidence tab.')),
        ]),
        backgroundColor: const Color(0xFF2EA073),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            context.push('$detailPath?tab=3');
          },
        ),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to attach: $e')),
        );
      }
    }
  }

  // ── Share methods ─────────────────────────────────────────────────────────

  Future<void> _shareViaEmail() async {
    final toolName = widget.tool.name;
    final subject = Uri.encodeComponent('$toolName — Analysis');
    final body = Uri.encodeComponent(
      'Please find the $toolName analysis from Reflect OS below.\n\n'
      'Generated: ${DateFormat("d MMM yyyy").format(widget.run.createdAt)}\n\n'
      'This report was generated using Reflect OS Decision Intelligence.',
    );
    final emailUri = Uri.parse('mailto:?subject=$subject&body=$body');
    await launchUrl(emailUri);

    if (_pdfBytes != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Download the PDF to attach it to your email'),
        action: SnackBarAction(
          label: 'Download',
          onPressed: _downloadPdf,
        ),
      ));
    }
  }

  Future<void> _shareViaSystem() async {
    if (kIsWeb) {
      // Web: fall back to PDF download.
      await _downloadPdf();
      return;
    }
    // Generate PDF bytes if not already cached.
    if (_pdfBytes == null) {
      await _downloadPdf();
    }
    final bytes = _pdfBytes;
    if (bytes == null || !mounted) return;
    final toolName = widget.tool.name.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '');
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: '$toolName.pdf', mimeType: 'application/pdf')],
      subject: widget.tool.name,
    );
  }

  // ── Save to device ────────────────────────────────────────────────────────

  Future<void> _saveToDevice() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      if (_pdfBytes == null) await _downloadPdf();
      final bytes = _pdfBytes;
      if (bytes == null || !mounted) return;

      final toolName = widget.tool.name.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '');
      final fileName = '${toolName}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (kIsWeb) {
        downloadPdfBlob(bytes, fileName);
      } else {
        // On mobile/desktop: use Printing to trigger OS save dialog.
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Share to Chat ─────────────────────────────────────────────────────────

  Future<void> _shareToChat() async {
    if (_isSharingChat) return;
    setState(() => _isSharingChat = true);
    try {
      if (_pdfBytes == null) await _downloadPdf();
      final bytes = _pdfBytes;
      if (bytes == null || !mounted) return;

      final workspaceId = ref.read(currentWorkspaceProvider).valueOrNull;
      final userId = supabase.auth.currentUser?.id;
      if (workspaceId == null || userId == null) return;

      final toolName = widget.tool.name.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '');
      final fileName = '$toolName.pdf';
      final storagePath = '$workspaceId/$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      // Upload PDF to chat-attachments bucket.
      await supabase.storage
          .from('chat-attachments')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: false,
            ),
          );

      // Insert chat message.
      final messageRow = await supabase
          .from('chat_messages')
          .insert({
            'workspace_id':   workspaceId,
            'sender_user_id': userId,
            'content':        'Shared toolkit report: ${widget.tool.name}',
            'has_attachment': true,
          })
          .select('id')
          .single();

      final messageId = messageRow['id'] as String;

      // Insert attachment row.
      await supabase.from('chat_attachments').insert({
        'message_id':      messageId,
        'workspace_id':    workspaceId,
        'uploaded_by':     userId,
        'file_name':       fileName,
        'file_size_bytes': bytes.length,
        'mime_type':       'application/pdf',
        'storage_path':    storagePath,
        'is_image':        false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shared to team chat'),
            backgroundColor: Color(0xFF2EA073),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share to chat: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharingChat = false);
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
          if (result.annualProjections.isNotEmpty) ...[
            _SectionHeader(title: 'Chart'),
            _ToolChart(
              toolKey: tool.key,
              projections: result.annualProjections
                  .map((r) => r as Map<String, dynamic>)
                  .toList(),
              currencyCode: widget.run.currencyCode,
            ),
            const SizedBox(height: 20),
          ],

          // Section 6 — Action bar: attach, share, download
          _ResultsActionBar(
            workspaceId:
                ref.watch(currentWorkspaceProvider).valueOrNull ?? '',
            attachedDecisionId: _attachedDecisionId,
            isDownloading:   _isDownloading,
            isSaving:        _isSaving,
            isSharingChat:   _isSharingChat,
            onDecisionSelected: _attachToDecision,
            onShareEmail:    _shareViaEmail,
            onShareSystem:   _shareViaSystem,
            onDownloadPdf:   _downloadPdf,
            onSaveToDevice:  _saveToDevice,
            onShareToChat:   _shareToChat,
          ),
          const SizedBox(height: 20),

          // Section 7 — Picker mode: attach output back to decision form
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
    required this.toolKey,
    required this.projections,
    this.currencyCode = 'GBP',
  });

  final String toolKey;
  final List<Map<String, dynamic>> projections;
  final String currencyCode;

  static const _chartH = 240.0;

  // ── Helpers ───────────────────────────────────────────────────────────────

  double _n(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

  String _xLabel(Map<String, dynamic> row, int index) {
    for (final k in ['year', 'month', 'week']) {
      final v = row[k];
      if (v != null) return v.toString();
    }
    return '${index + 1}';
  }

  static FlGridData _grid() => FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => const FlLine(
          color: Color(0x26808080),
          strokeWidth: 1,
        ),
      );

  FlTitlesData _xTitles(BuildContext context, int count) {
    final rotate = count > 8;
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 56,
          getTitlesWidget: (v, _) => Text(
            _fmtShort(v),
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
      rightTitles: const AxisTitles(),
      topTitles: const AxisTitles(),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: rotate ? 38 : 22,
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (v != i.toDouble() || i < 0 || i >= projections.length) {
              return const SizedBox.shrink();
            }
            final lbl = _xLabel(projections[i], i);
            if (rotate) {
              return Transform.rotate(
                angle: -math.pi / 4,
                child: Text(lbl, style: TextStyle(fontSize: 9,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
              );
            }
            return Text(lbl, style: TextStyle(fontSize: 9,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)));
          },
        ),
      ),
    );
  }

  static Widget _card(BuildContext context, Widget child) => Card(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: child,
        ),
      );

  static Widget _legend(BuildContext context, List<_LegendEntry> entries) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: entries.map((e) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 3,
                decoration: BoxDecoration(color: e.color, borderRadius: AppRadius.xsBR)),
            const SizedBox(width: 4),
            Text(e.label, style: TextStyle(fontSize: 10,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
          ],
        )).toList(),
      ),
    );
  }

  String _fmtShort(double v) {
    if (v.abs() >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }

  // ── Dispatch ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (projections.isEmpty) return const SizedBox.shrink();

    return switch (toolKey) {
      'roi_calculator_v2' => _roiLines(context),
      'break_even_calculator_v2' => _breakEvenLines(context),
      'pricing_change_impact_v2' => _pricingLines(context),
      'cost_of_inaction_v2' => _coiBar(context),
      'headcount_runway_v2' => _headcountLines(context),
      'scenario_builder_v2' => _fanBand(context,
          upperKey: 'best_case', baseKey: 'expected_case', lowerKey: 'worst_case',
          upperLabel: 'Best', baseLabel: 'Expected', lowerLabel: 'Worst'),
      'reference_class_forecast_v2' => _fanBand(context,
          upperKey: 'optimistic', baseKey: 'base_forecast', lowerKey: 'pessimistic',
          upperLabel: 'Optimistic', baseLabel: 'Base', lowerLabel: 'Pessimistic'),
      'sensitivity_analysis_v2' => _tornadoChart(context),
      'risk_matrix_v2' => _riskBubbles(context),
      'attrition_risk_v2' => _attritionBars(context),
      'hiring_success_ramp_v2' => _hiringLines(context),
      'reorg_impact_v2' => _reorgLines(context),
      'ab_test_calculator_v2' || 'delivery_confidence_v2' => _confidenceBand(context),
      'stakeholder_alignment_v2' => _stakeholderBars(context),
      'outcome_metric_builder_v2' => _progressBars(context),
      'base_rate_lookup_v2' => _baseRateBars(context),
      _ => _fallbackBar(context),
    };
  }

  // ── ROI: revenue / ongoing cost / net cashflow lines ─────────────────────

  Widget _roiLines(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    double maxY = 0, minY = 0;
    final benefitSpots = <FlSpot>[];
    final costSpots    = <FlSpot>[];
    final netSpots     = <FlSpot>[];

    for (var i = 0; i < projections.length; i++) {
      final r = projections[i];
      final b = _n(r['benefit']);
      final c = _n(r['ongoing_cost']);
      final n = _n(r['net_cashflow']);
      benefitSpots.add(FlSpot(i.toDouble(), b));
      costSpots.add(FlSpot(i.toDouble(), c));
      netSpots.add(FlSpot(i.toDouble(), n));
      maxY = math.max(maxY, math.max(b, math.max(c, n)));
      minY = math.min(minY, n);
    }

    return _card(context, Column(children: [
      SizedBox(height: _chartH, child: LineChart(LineChartData(
        minY: minY * 1.15,
        maxY: maxY * 1.25,
        borderData: FlBorderData(show: false),
        gridData: _grid(),
        titlesData: _xTitles(context, projections.length),
        lineBarsData: [
          _line(benefitSpots, cs.primary),
          _line(costSpots, cs.error),
          _line(netSpots, cs.tertiary,
              belowBar: BarAreaData(show: true,
                  color: cs.tertiary.withValues(alpha: 0.1))),
        ],
      ))),
      _legend(context, [
        _LegendEntry(cs.primary, 'Revenue'),
        _LegendEntry(cs.error, 'Costs'),
        _LegendEntry(cs.tertiary, 'Net'),
      ]),
    ]));
  }

  // ── Break-Even: revenue / total costs / profit lines ─────────────────────

  Widget _breakEvenLines(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    double maxY = 0, minY = 0;
    final revSpots  = <FlSpot>[];
    final costSpots = <FlSpot>[];
    final plSpots   = <FlSpot>[];

    for (var i = 0; i < projections.length; i++) {
      final r = projections[i];
      final rev  = _n(r['revenue']);
      final cost = _n(r['variable_costs']) + _n(r['fixed_costs']);
      final pl   = _n(r['profit_loss']);
      revSpots.add(FlSpot(i.toDouble(), rev));
      costSpots.add(FlSpot(i.toDouble(), cost));
      plSpots.add(FlSpot(i.toDouble(), pl));
      maxY = math.max(maxY, math.max(rev, cost));
      minY = math.min(minY, pl);
    }

    return _card(context, Column(children: [
      SizedBox(height: _chartH, child: LineChart(LineChartData(
        minY: minY * 1.15,
        maxY: maxY * 1.25,
        borderData: FlBorderData(show: false),
        gridData: _grid(),
        titlesData: _xTitles(context, projections.length),
        lineBarsData: [
          _line(revSpots, cs.primary),
          _line(costSpots, cs.error),
          _line(plSpots, cs.secondary,
              belowBar: BarAreaData(show: true,
                  color: cs.secondary.withValues(alpha: 0.08))),
        ],
      ))),
      _legend(context, [
        _LegendEntry(cs.primary, 'Revenue'),
        _LegendEntry(cs.error, 'Total Costs'),
        _LegendEntry(cs.secondary, 'Profit / Loss'),
      ]),
    ]));
  }

  // ── Pricing: revenue / COGS / gross profit ────────────────────────────────

  Widget _pricingLines(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    double maxY = 0, minY = 0;
    final revSpots = <FlSpot>[];
    final gpSpots  = <FlSpot>[];
    final cogsSpots = <FlSpot>[];

    for (var i = 0; i < projections.length; i++) {
      final r = projections[i];
      final rev  = _n(r['revenue']);
      final gp   = _n(r['gross_profit']);
      final cogs = _n(r['cogs']);
      revSpots.add(FlSpot(i.toDouble(), rev));
      gpSpots.add(FlSpot(i.toDouble(), gp));
      cogsSpots.add(FlSpot(i.toDouble(), cogs));
      maxY = math.max(maxY, math.max(rev, gp));
      minY = math.min(minY, gp);
    }

    return _card(context, Column(children: [
      SizedBox(height: _chartH, child: LineChart(LineChartData(
        minY: minY < 0 ? minY * 1.15 : 0,
        maxY: maxY * 1.25,
        borderData: FlBorderData(show: false),
        gridData: _grid(),
        titlesData: _xTitles(context, projections.length),
        lineBarsData: [
          _line(revSpots, cs.primary),
          _line(cogsSpots, cs.error),
          _line(gpSpots, cs.tertiary,
              belowBar: BarAreaData(show: true,
                  color: cs.tertiary.withValues(alpha: 0.1))),
        ],
      ))),
      _legend(context, [
        _LegendEntry(cs.primary, 'Revenue'),
        _LegendEntry(cs.error, 'COGS'),
        _LegendEntry(cs.tertiary, 'Gross Profit'),
      ]),
    ]));
  }

  // ── Cost of Inaction: monthly costs bar chart ─────────────────────────────

  Widget _coiBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final show = projections.take(24).toList();
    double maxY = 0;
    final groups = show.asMap().entries.map((e) {
      final r    = e.value;
      final mc   = _n(r['monthly_cost']);
      final opp  = _n(r['opportunity_cost']);
      maxY = math.max(maxY, mc + opp);
      return BarChartGroupData(x: e.key, barRods: [
        BarChartRodData(toY: mc, color: cs.error.withValues(alpha: 0.8),
            width: 6, borderRadius: AppRadius.xsBR),
        BarChartRodData(toY: opp, color: cs.primary.withValues(alpha: 0.5),
            width: 6, borderRadius: AppRadius.xsBR),
      ]);
    }).toList();

    return _card(context, Column(children: [
      SizedBox(height: _chartH, child: BarChart(BarChartData(
        maxY: maxY * 1.25,
        borderData: FlBorderData(show: false),
        gridData: _grid(),
        barTouchData: BarTouchData(enabled: false),
        titlesData: _xTitles(context, show.length),
        barGroups: groups,
      ))),
      _legend(context, [
        _LegendEntry(cs.error.withValues(alpha: 0.8), 'Monthly Cost'),
        _LegendEntry(cs.primary.withValues(alpha: 0.5), 'Opportunity Cost'),
      ]),
    ]));
  }

  // ── Headcount: cash balance lines ─────────────────────────────────────────

  Widget _headcountLines(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final show = projections.take(24).toList();
    double maxY = 0, minY = 0;
    final baseSpots = <FlSpot>[];
    final newSpots  = <FlSpot>[];

    for (var i = 0; i < show.length; i++) {
      final r = show[i];
      final b = _n(r['cash_balance_base']);
      final n = _n(r['cash_balance_new']);
      baseSpots.add(FlSpot(i.toDouble(), b));
      newSpots.add(FlSpot(i.toDouble(), n));
      maxY = math.max(maxY, math.max(b, n));
      minY = math.min(minY, math.min(b, n));
    }

    return _card(context, Column(children: [
      SizedBox(height: _chartH, child: LineChart(LineChartData(
        minY: minY < 0 ? minY * 1.15 : 0,
        maxY: maxY * 1.25,
        borderData: FlBorderData(show: false),
        gridData: _grid(),
        titlesData: _xTitles(context, show.length),
        lineBarsData: [
          _line(baseSpots, cs.secondary),
          _line(newSpots, cs.primary),
        ],
      ))),
      _legend(context, [
        _LegendEntry(cs.secondary, 'Current trajectory'),
        _LegendEntry(cs.primary, 'With headcount change'),
      ]),
    ]));
  }

  // ── Fan/band chart (scenario, reference class) ────────────────────────────

  Widget _fanBand(BuildContext context, {
    required String upperKey, required String baseKey, required String lowerKey,
    required String upperLabel, required String baseLabel, required String lowerLabel,
  }) {
    final cs = Theme.of(context).colorScheme;
    double maxY = 0, minY = 0;
    final upperSpots = <FlSpot>[];
    final baseSpots  = <FlSpot>[];
    final lowerSpots = <FlSpot>[];

    for (var i = 0; i < projections.length; i++) {
      final r = projections[i];
      final u = _n(r[upperKey]);
      final b = _n(r[baseKey]);
      final l = _n(r[lowerKey]);
      upperSpots.add(FlSpot(i.toDouble(), u));
      baseSpots.add(FlSpot(i.toDouble(), b));
      lowerSpots.add(FlSpot(i.toDouble(), l));
      maxY = math.max(maxY, u);
      minY = math.min(minY, l);
    }

    return _card(context, Column(children: [
      SizedBox(height: _chartH, child: LineChart(LineChartData(
        minY: minY < 0 ? minY * 1.15 : minY * 0.8,
        maxY: maxY * 1.25,
        borderData: FlBorderData(show: false),
        gridData: _grid(),
        titlesData: _xTitles(context, projections.length),
        betweenBarsData: [
          BetweenBarsData(fromIndex: 0, toIndex: 2,
              color: cs.primary.withValues(alpha: 0.08)),
        ],
        lineBarsData: [
          // upper — index 0 (referenced by betweenBarsData)
          LineChartBarData(spots: upperSpots, isCurved: true,
              color: cs.primary.withValues(alpha: 0.4), barWidth: 1.5,
              dotData: const FlDotData(show: false)),
          // base — index 1
          LineChartBarData(spots: baseSpots, isCurved: true,
              color: cs.primary, barWidth: 2.5,
              dotData: FlDotData(show: true,
                  getDotPainter: (p0, p1, p2, p3) =>
                      FlDotCirclePainter(radius: 3, color: cs.primary,
                          strokeWidth: 0, strokeColor: Colors.transparent))),
          // lower — index 2 (referenced by betweenBarsData)
          LineChartBarData(spots: lowerSpots, isCurved: true,
              color: cs.primary.withValues(alpha: 0.4), barWidth: 1.5,
              dotData: const FlDotData(show: false)),
        ],
      ))),
      _legend(context, [
        _LegendEntry(cs.primary.withValues(alpha: 0.4), upperLabel),
        _LegendEntry(cs.primary, baseLabel),
        _LegendEntry(cs.primary.withValues(alpha: 0.4), lowerLabel),
      ]),
    ]));
  }

  // ── Sensitivity: tornado horizontal bars ─────────────────────────────────

  Widget _tornadoChart(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final show = projections.take(10).toList();
    final vals = show.map((r) => _n(r['swing_range'])).toList();
    final maxV = vals.fold(0.0, math.max).clamp(1.0, double.infinity);
    const rowH = 36.0;
    const labelW = 110.0;

    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        child: SizedBox(
          height: math.max(180.0, show.length * rowH + 24),
          child: LayoutBuilder(builder: (ctx, box) {
            final barW = (box.maxWidth - labelW - 8).clamp(40.0, double.infinity);
            return Column(
              children: show.asMap().entries.map((e) {
                final r    = e.value;
                final lbl  = (r['label'] as String?) ?? '${e.key + 1}';
                final frac = vals[e.key] / maxV;
                return SizedBox(
                  height: rowH,
                  child: Row(children: [
                    SizedBox(width: labelW,
                        child: Text(lbl, textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10,
                                color: cs.onSurface.withValues(alpha: 0.7)))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: barW * frac,
                          height: 22,
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.7),
                            borderRadius: AppRadius.xsBR,
                          ),
                        ),
                      ),
                    ),
                  ]),
                );
              }).toList(),
            );
          }),
        ),
      ),
    );
  }

  // ── Risk Matrix: horizontal risk-score bars ───────────────────────────────

  Widget _riskBubbles(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final show = projections.take(10).toList();
    double maxV = 1;
    for (final r in show) { maxV = math.max(maxV, _n(r['risk_score'])); }
    const rowH = 36.0;
    const labelW = 120.0;

    Color riskColor(String? level) => switch (level) {
      'Critical' => cs.error,
      'High'     => Colors.orange,
      'Medium'   => Colors.amber,
      _          => cs.secondary,
    };

    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        child: SizedBox(
          height: math.max(180.0, show.length * rowH + 24),
          child: LayoutBuilder(builder: (ctx, box) {
            final barW = (box.maxWidth - labelW - 8).clamp(40.0, double.infinity);
            return Column(
              children: show.asMap().entries.map((e) {
                final r     = e.value;
                final lbl   = (r['label'] as String?) ?? '${e.key + 1}';
                final score = _n(r['risk_score']);
                final level = r['risk_level'] as String?;
                final frac  = score / maxV;
                return SizedBox(
                  height: rowH,
                  child: Row(children: [
                    SizedBox(width: labelW,
                        child: Text(lbl, textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10,
                                color: cs.onSurface.withValues(alpha: 0.7)))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: barW * frac,
                          height: 22,
                          decoration: BoxDecoration(
                            color: riskColor(level).withValues(alpha: 0.7),
                            borderRadius: AppRadius.xsBR,
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: score > 0 ? Text(score.toStringAsFixed(0),
                              style: const TextStyle(fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)) : null,
                        ),
                      ),
                    ),
                  ]),
                );
              }).toList(),
            );
          }),
        ),
      ),
    );
  }

  // ── Attrition: grouped cost vs investment bars ────────────────────────────

  Widget _attritionBars(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    double maxY = 0;
    final groups = projections.asMap().entries.map((e) {
      final r    = e.value;
      final cost = _n(r['attrition_cost']);
      final inv  = _n(r['retention_investment']);
      maxY = math.max(maxY, cost);
      return BarChartGroupData(x: e.key, groupVertically: false, barRods: [
        BarChartRodData(toY: cost, color: cs.error.withValues(alpha: 0.8),
            width: 12, borderRadius: AppRadius.xsBR),
        BarChartRodData(toY: inv, color: cs.primary.withValues(alpha: 0.7),
            width: 12, borderRadius: AppRadius.xsBR),
      ], barsSpace: 4);
    }).toList();

    return _card(context, Column(children: [
      SizedBox(height: _chartH, child: BarChart(BarChartData(
        maxY: maxY * 1.25,
        borderData: FlBorderData(show: false),
        gridData: _grid(),
        barTouchData: BarTouchData(enabled: false),
        titlesData: _xTitles(context, projections.length),
        barGroups: groups,
      ))),
      _legend(context, [
        _LegendEntry(cs.error.withValues(alpha: 0.8), 'Attrition Cost'),
        _LegendEntry(cs.primary.withValues(alpha: 0.7), 'Retention Investment'),
      ]),
    ]));
  }

  // ── Hiring: value generated vs salary cost + cumulative ──────────────────

  Widget _hiringLines(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final show = projections.take(24).toList();
    double maxY = 0, minY = 0;
    final valSpots  = <FlSpot>[];
    final costSpots = <FlSpot>[];
    final cumSpots  = <FlSpot>[];

    for (var i = 0; i < show.length; i++) {
      final r = show[i];
      final v = _n(r['value_generated']);
      final c = _n(r['salary_cost']);
      final n = _n(r['cumulative_net']);
      valSpots.add(FlSpot(i.toDouble(), v));
      costSpots.add(FlSpot(i.toDouble(), c));
      cumSpots.add(FlSpot(i.toDouble(), n));
      maxY = math.max(maxY, math.max(v, c));
      minY = math.min(minY, n);
    }

    return _card(context, Column(children: [
      SizedBox(height: _chartH, child: LineChart(LineChartData(
        minY: minY < 0 ? minY * 1.15 : 0,
        maxY: maxY * 1.25,
        borderData: FlBorderData(show: false),
        gridData: _grid(),
        titlesData: _xTitles(context, show.length),
        lineBarsData: [
          _line(valSpots, cs.primary),
          _line(costSpots, cs.error),
          _line(cumSpots, cs.tertiary,
              belowBar: BarAreaData(show: true,
                  color: cs.tertiary.withValues(alpha: 0.1))),
        ],
      ))),
      _legend(context, [
        _LegendEntry(cs.primary, 'Value Generated'),
        _LegendEntry(cs.error, 'Salary Cost'),
        _LegendEntry(cs.tertiary, 'Cumulative Net'),
      ]),
    ]));
  }

  // ── Reorg: efficiency saving vs cumulative net ────────────────────────────

  Widget _reorgLines(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final show = projections.take(36).toList();
    double maxY = 0, minY = 0;
    final savingSpots = <FlSpot>[];
    final cumSpots    = <FlSpot>[];

    for (var i = 0; i < show.length; i++) {
      final r = show[i];
      final s = _n(r['efficiency_saving']);
      final c = _n(r['cumulative_net']);
      savingSpots.add(FlSpot(i.toDouble(), s));
      cumSpots.add(FlSpot(i.toDouble(), c));
      maxY = math.max(maxY, s);
      minY = math.min(minY, c);
    }

    return _card(context, Column(children: [
      SizedBox(height: _chartH, child: LineChart(LineChartData(
        minY: minY < 0 ? minY * 1.15 : 0,
        maxY: maxY * 1.25,
        borderData: FlBorderData(show: false),
        gridData: _grid(),
        titlesData: _xTitles(context, show.length),
        lineBarsData: [
          _line(savingSpots, cs.primary),
          _line(cumSpots, cs.tertiary,
              belowBar: BarAreaData(show: true,
                  color: cs.tertiary.withValues(alpha: 0.08))),
        ],
      ))),
      _legend(context, [
        _LegendEntry(cs.primary, 'Monthly Saving'),
        _LegendEntry(cs.tertiary, 'Cumulative Net'),
      ]),
    ]));
  }

  // ── A/B test & Delivery: confidence band ─────────────────────────────────

  Widget _confidenceBand(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    double maxY = 0, minY = 100;
    final metricSpots = <FlSpot>[];
    final upperSpots  = <FlSpot>[];
    final lowerSpots  = <FlSpot>[];

    for (var i = 0; i < projections.length; i++) {
      final r = projections[i];
      final m = _n(r['metric']);
      final u = _n(r['upper_bound']);
      final l = _n(r['lower_bound']);
      metricSpots.add(FlSpot(i.toDouble(), m));
      upperSpots.add(FlSpot(i.toDouble(), u));
      lowerSpots.add(FlSpot(i.toDouble(), l));
      maxY = math.max(maxY, u);
      minY = math.min(minY, l);
    }

    return _card(context, Column(children: [
      SizedBox(height: _chartH, child: LineChart(LineChartData(
        minY: (minY - 5).clamp(0, 100),
        maxY: (maxY + 5).clamp(0, 110),
        borderData: FlBorderData(show: false),
        gridData: _grid(),
        titlesData: _xTitles(context, projections.length),
        betweenBarsData: [
          BetweenBarsData(fromIndex: 0, toIndex: 2,
              color: cs.primary.withValues(alpha: 0.1)),
        ],
        lineBarsData: [
          // upper — index 0
          LineChartBarData(spots: upperSpots, isCurved: true,
              color: cs.primary.withValues(alpha: 0.3), barWidth: 1,
              dotData: const FlDotData(show: false)),
          // metric — index 1
          _line(metricSpots, cs.primary),
          // lower — index 2
          LineChartBarData(spots: lowerSpots, isCurved: true,
              color: cs.primary.withValues(alpha: 0.3), barWidth: 1,
              dotData: const FlDotData(show: false)),
        ],
      ))),
      _legend(context, [
        _LegendEntry(cs.primary.withValues(alpha: 0.3), '95% CI'),
        _LegendEntry(cs.primary, 'Metric'),
      ]),
    ]));
  }

  // ── Stakeholder: influence × support bars ─────────────────────────────────

  Widget _stakeholderBars(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final show = projections.take(12).toList();
    final groups = show.asMap().entries.map((e) {
      final r = e.value;
      final inf = _n(r['influence']);
      final sup = _n(r['support']);
      return BarChartGroupData(x: e.key, barRods: [
        BarChartRodData(toY: inf, color: cs.primary.withValues(alpha: 0.8),
            width: 10, borderRadius: AppRadius.xsBR),
        BarChartRodData(toY: sup, color: cs.secondary.withValues(alpha: 0.8),
            width: 10, borderRadius: AppRadius.xsBR),
      ], barsSpace: 4);
    }).toList();

    return _card(context, Column(children: [
      SizedBox(height: _chartH, child: BarChart(BarChartData(
        maxY: 5.5,
        borderData: FlBorderData(show: false),
        gridData: _grid(),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 24,
            getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0),
                style: TextStyle(fontSize: 9,
                    color: cs.onSurface.withValues(alpha: 0.6))),
          )),
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 52,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= show.length) return const SizedBox.shrink();
              final name = (show[i]['name'] as String?) ?? '${i + 1}';
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Transform.rotate(
                  angle: -math.pi / 4,
                  child: Text(name, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 9,
                          color: cs.onSurface.withValues(alpha: 0.7))),
                ),
              );
            },
          )),
        ),
        barGroups: groups,
      ))),
      _legend(context, [
        _LegendEntry(cs.primary.withValues(alpha: 0.8), 'Influence (1–5)'),
        _LegendEntry(cs.secondary.withValues(alpha: 0.8), 'Support (1–5)'),
      ]),
    ]));
  }

  // ── Outcome Metric Builder: progress bars ─────────────────────────────────

  Widget _progressBars(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final show = projections.where((r) => r['progress'] != null).take(10).toList();
    if (show.isEmpty) return _fallbackBar(context);

    final groups = show.asMap().entries.map((e) {
      final progress = _n(e.value['progress']).clamp(0.0, 100.0);
      final color = progress >= 80
          ? Colors.green.withValues(alpha: 0.8)
          : progress >= 50
              ? Colors.amber.withValues(alpha: 0.8)
              : cs.error.withValues(alpha: 0.8);
      return BarChartGroupData(x: e.key, barRods: [
        BarChartRodData(toY: progress, color: color, width: 20,
            borderRadius: AppRadius.xsBR),
      ]);
    }).toList();

    final labels = show.map((r) => (r['label'] as String?) ?? '').toList();

    return _card(context, SizedBox(
      height: _chartH,
      child: BarChart(BarChartData(
        maxY: 110,
        borderData: FlBorderData(show: false),
        gridData: _grid(),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 32,
            getTitlesWidget: (v, _) => Text('${v.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 9,
                    color: cs.onSurface.withValues(alpha: 0.6))),
          )),
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 52,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= labels.length) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Transform.rotate(
                  angle: -math.pi / 4,
                  child: Text(labels[i], overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 9,
                          color: cs.onSurface.withValues(alpha: 0.7))),
                ),
              );
            },
          )),
        ),
        barGroups: groups,
      )),
    ));
  }

  // ── Base Rate: 3-bar comparison ───────────────────────────────────────────

  Widget _baseRateBars(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final labels = projections.map((r) => (r['label'] as String?) ?? '').toList();
    final vals   = projections.map((r) => _n(r['metric'])).toList();
    final maxY   = vals.fold(0.0, math.max).clamp(1.0, 100.0);
    final colors = [cs.secondary, cs.error, cs.primary];

    final groups = projections.asMap().entries.map((e) {
      return BarChartGroupData(x: e.key, barRods: [
        BarChartRodData(toY: vals[e.key],
            color: colors[e.key % colors.length].withValues(alpha: 0.8),
            width: 40, borderRadius: AppRadius.xsBR),
      ]);
    }).toList();

    return _card(context, Column(children: [
      SizedBox(height: _chartH - 40, child: BarChart(BarChartData(
        maxY: maxY * 1.25,
        borderData: FlBorderData(show: false),
        gridData: _grid(),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 32,
            getTitlesWidget: (v, _) => Text('${v.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 9,
                    color: cs.onSurface.withValues(alpha: 0.6))),
          )),
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 20,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= labels.length) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(labels[i], style: TextStyle(fontSize: 10,
                    color: cs.onSurface.withValues(alpha: 0.7))),
              );
            },
          )),
        ),
        barGroups: groups,
      ))),
      _legend(context, labels.asMap().entries.map((e) =>
          _LegendEntry(colors[e.key % colors.length], '${vals[e.key].toStringAsFixed(1)}%')).toList()),
    ]));
  }

  // ── Fallback: generic bar chart ───────────────────────────────────────────

  Widget _fallbackBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Try to find any numeric key to plot
    final numKeys = projections.first.entries
        .where((e) => e.value is num && e.key != 'year' && e.key != 'month')
        .map((e) => e.key)
        .take(3)
        .toList();
    if (numKeys.isEmpty) return const SizedBox.shrink();

    double maxY = 0;
    final palette = [cs.primary, cs.secondary, cs.tertiary];
    final seriesSpots = numKeys.map((_) => <FlSpot>[]).toList();

    for (var i = 0; i < projections.length; i++) {
      final r = projections[i];
      for (var k = 0; k < numKeys.length; k++) {
        final v = _n(r[numKeys[k]]);
        seriesSpots[k].add(FlSpot(i.toDouble(), v));
        maxY = math.max(maxY, v.abs());
      }
    }

    return _card(context, Column(children: [
      SizedBox(height: _chartH, child: LineChart(LineChartData(
        maxY: maxY * 1.25,
        borderData: FlBorderData(show: false),
        gridData: _grid(),
        titlesData: _xTitles(context, projections.length),
        lineBarsData: seriesSpots.asMap().entries.map((e) =>
            _line(e.value, palette[e.key % palette.length])).toList(),
      ))),
      _legend(context, numKeys.asMap().entries.map((e) =>
          _LegendEntry(palette[e.key % palette.length], e.value)).toList()),
    ]));
  }

  // ── Shared line builder ───────────────────────────────────────────────────

  LineChartBarData _line(List<FlSpot> spots, Color color,
      {BarAreaData? belowBar}) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2.5,
      dotData: FlDotData(
        show: true,
        getDotPainter: (p0, p1, p2, p3) => FlDotCirclePainter(
          radius: 3,
          color: color,
          strokeWidth: 0,
          strokeColor: Colors.transparent,
        ),
      ),
      belowBarData: belowBar ?? BarAreaData(show: false),
    );
  }
}

class _LegendEntry {
  const _LegendEntry(this.color, this.label);
  final Color color;
  final String label;
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

// ── Results action bar ────────────────────────────────────────────────────────

class _ResultsActionBar extends StatelessWidget {
  const _ResultsActionBar({
    required this.workspaceId,
    required this.attachedDecisionId,
    required this.isDownloading,
    required this.isSaving,
    required this.isSharingChat,
    required this.onDecisionSelected,
    required this.onShareEmail,
    required this.onShareSystem,
    required this.onDownloadPdf,
    required this.onSaveToDevice,
    required this.onShareToChat,
  });

  final String workspaceId;
  final String? attachedDecisionId;
  final bool isDownloading;
  final bool isSaving;
  final bool isSharingChat;
  final Future<void> Function(String decisionId) onDecisionSelected;
  final Future<void> Function() onShareEmail;
  final Future<void> Function() onShareSystem;
  final Future<void> Function() onDownloadPdf;
  final Future<void> Function() onSaveToDevice;
  final Future<void> Function() onShareToChat;

  static const _teal = Color(0xFF19CBD6);

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final busy = isDownloading || isSaving || isSharingChat;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.backgroundSecondary,
        borderRadius: AppRadius.mdBR,
        border: Border.all(color: cs.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Attach to decision
          Row(
            children: [
              const Icon(Icons.link, color: _teal, size: 16),
              const SizedBox(width: 8),
              Text(
                'Attach to a decision:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DecisionPickerDropdown(
                  workspaceId: workspaceId,
                  attachedDecisionId: attachedDecisionId,
                  onDecisionSelected: onDecisionSelected,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Sharing buttons — platform-aware
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.email_outlined, size: 15),
                label: const Text('Email'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _teal,
                  side: BorderSide(color: cs.borderDefault),
                ),
                onPressed: busy ? null : onShareEmail,
              ),
              // Share (native share sheet) — mobile only
              if (!kIsWeb)
                OutlinedButton.icon(
                  icon: const Icon(Icons.share_outlined, size: 15),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _teal,
                    side: BorderSide(color: cs.borderDefault),
                  ),
                  onPressed: busy ? null : onShareSystem,
                ),
              FilledButton.icon(
                icon: isDownloading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.picture_as_pdf, size: 15),
                label: Text(isDownloading ? 'Building…' : 'Download PDF'),
                style: FilledButton.styleFrom(backgroundColor: _teal),
                onPressed: busy ? null : onDownloadPdf,
              ),
              // Save to Device — mobile only (web uses Download PDF)
              if (!kIsWeb)
                OutlinedButton.icon(
                  icon: isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _teal),
                        )
                      : const Icon(Icons.save_alt, size: 15),
                  label: Text(isSaving ? 'Saving…' : 'Save to Device'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _teal,
                    side: BorderSide(color: cs.borderDefault),
                  ),
                  onPressed: busy ? null : onSaveToDevice,
                ),
              OutlinedButton.icon(
                icon: isSharingChat
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _teal),
                      )
                    : const Icon(Icons.chat_bubble_outline, size: 15),
                label: Text(isSharingChat ? 'Sharing…' : 'Share to Chat'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _teal,
                  side: BorderSide(color: cs.borderDefault),
                ),
                onPressed: busy ? null : onShareToChat,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Decision picker dropdown ───────────────────────────────────────────────────

class _DecisionPickerDropdown extends ConsumerWidget {
  const _DecisionPickerDropdown({
    required this.workspaceId,
    required this.attachedDecisionId,
    required this.onDecisionSelected,
  });

  final String workspaceId;
  final String? attachedDecisionId;
  final Future<void> Function(String decisionId) onDecisionSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decisionsAsync = ref.watch(decisionsProvider);
    final decisions = decisionsAsync.valueOrNull
            ?.where((d) => d.state != 'Archived')
            .toList() ??
        [];

    return DropdownButtonFormField<String>(
      initialValue: attachedDecisionId,
      isDense: true,
      decoration: InputDecoration(
        hintText: 'Select a decision…',
        hintStyle:
            TextStyle(fontSize: 12, color: context.cs.textTertiary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: AppRadius.smBR,
          borderSide: BorderSide(color: context.cs.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBR,
          borderSide: BorderSide(color: context.cs.borderDefault),
        ),
        isDense: true,
      ),
      items: decisions.map((d) {
        return DropdownMenuItem<String>(
          value: d.id,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  d.title,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF19CBD6).withValues(alpha: 0.1),
                  borderRadius: AppRadius.smBR,
                ),
                child: Text(
                  d.state,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF19CBD6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (id) {
        if (id != null) onDecisionSelected(id);
      },
    );
  }
}

