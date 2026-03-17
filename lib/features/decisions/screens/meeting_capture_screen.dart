import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/decisions/data/models/create_decision_input.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';
import 'package:reflect_os/widgets/app_header.dart';

class MeetingCaptureScreen extends ConsumerStatefulWidget {
  const MeetingCaptureScreen({super.key, this.mode, this.source});

  /// 'multiple' → POST mode:multiple, handle bulk review step.
  /// null / any other value → single-decision mode (default).
  final String? mode;

  /// 'add_decision' → when extraction yields a single decision, pop back
  /// with the result data instead of pushing a new CreateDecisionScreen.
  final String? source;

  @override
  ConsumerState<MeetingCaptureScreen> createState() =>
      _MeetingCaptureScreenState();
}

class _MeetingCaptureScreenState
    extends ConsumerState<MeetingCaptureScreen> {
  final _notesController = TextEditingController();
  bool _isExtracting = false;
  String? _errorMessage;

  // Review step state (multiple mode, count > 1)
  bool _inReviewMode = false;
  List<Map<String, dynamic>> _extractedDecisions = [];
  Set<int> _selectedIndices = {};
  bool _isCreating = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  int get _wordCount {
    final text = _notesController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  Future<void> _extract() async {
    final notes = _notesController.text.trim();
    if (notes.isEmpty) return;

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
    });

    try {
      // Refresh session if the stored token is missing or expired.
      var session = supabase.auth.currentSession;
      if (session == null) {
        final refreshed = await supabase.auth.refreshSession();
        session = refreshed.session;
      }
      if (session == null) {
        throw Exception('Not authenticated — please sign in again.');
      }

      final uri = Uri.parse(
        '$supabaseProjectUrl/functions/v1/extract-decision-from-meeting',
      );

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'meeting_notes': notes, 'mode': 'multiple'}),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Server error ${response.statusCode}: ${response.body}');
      }

      // Response always: { "decisions": [...], "count": N }
      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      final decisions = (data?['decisions'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>();
      final count = data?['count'] as int? ?? decisions?.length ?? 0;

      if (decisions == null || decisions.isEmpty) {
        throw Exception('No decision could be extracted from these notes.');
      }

      if (!mounted) return;

      // ── Multiple decisions → review step ─────────────────────────────
      if (count > 1) {
        setState(() {
          _isExtracting = false;
          _extractedDecisions = decisions;
          _selectedIndices = Set.from(
            List.generate(decisions.length, (i) => i),
          );
          _inReviewMode = true;
        });
        return;
      }

      // ── Single decision ───────────────────────────────────────────────
      final single = decisions.first;
      final result = <String, dynamic>{
        'title': single['title'] as String? ?? '',
        'description': single['description'] as String? ?? '',
        'stakes': single['stakes'] as String?,
        'category': single['category'] as String?,
        'fromMeeting': true,
      };
      if (widget.source == 'add_decision') {
        context.pop(result);
      } else {
        context.push(Routes.decisionsCreate, extra: result);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _errorMessage = 'Failed to extract decision: $e';
      });
    }
  }

  Future<void> _createSelected() async {
    final selected =
        _selectedIndices.map((i) => _extractedDecisions[i]).toList();
    if (selected.isEmpty) return;

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final workspaceId = await ref.read(currentWorkspaceProvider.future);
      if (workspaceId == null) {
        throw Exception('No workspace found. Please contact support.');
      }

      for (final d in selected) {
        final input = CreateDecisionInput(
          workspaceId: workspaceId,
          title: d['title'] as String? ?? '',
          stakes: d['stakes'] as String?,
          descriptionEncrypted: (d['description'] as String?)?.isEmpty == false
              ? d['description'] as String
              : null,
        );
        await ref.read(decisionsRepositoryProvider).createDecision(input);
      }

      ref.invalidate(decisionsProvider);

      if (!mounted) return;
      context.go(Routes.decisionsList);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selected.length} decision${selected.length == 1 ? '' : 's'} '
            'created from meeting notes',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _errorMessage = 'Failed to create decisions: $e';
      });
    }
  }

  void _fillManually() {
    context.push(Routes.decisionsCreate);
  }

  // ── Review step (multiple mode, count > 1) ────────────────────────────────

  Widget _buildReviewStep(BuildContext context) {
    final selectedCount = _selectedIndices.length;
    return Scaffold(
      appBar: AppHeader(
        title: 'Review Extracted Decisions',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => setState(() {
            _inReviewMode = false;
            _isExtracting = false;
          }),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Info card ───────────────────────────────────────────
                Card(
                  color: Theme.of(context).colorScheme.surface,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.auto_awesome_outlined,
                          size: 20,
                          color: Colors.teal,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${_extractedDecisions.length} decisions were '
                            'extracted from your notes. Select the ones you '
                            'want to create.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Decision cards ──────────────────────────────────────
                ..._extractedDecisions.asMap().entries.map((entry) {
                  final i = entry.key;
                  final d = entry.value;
                  final selected = _selectedIndices.contains(i);
                  return Card(
                    color: Theme.of(context).colorScheme.surface,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: selected
                            ? Colors.teal
                            : Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.3),
                      ),
                    ),
                    child: CheckboxListTile(
                      value: selected,
                      onChanged: (_) => setState(() {
                        if (selected) {
                          _selectedIndices.remove(i);
                        } else {
                          _selectedIndices.add(i);
                        }
                      }),
                      activeColor: Colors.teal,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding:
                          const EdgeInsets.fromLTRB(8, 8, 16, 8),
                      title: Text(
                        d['title'] as String? ?? 'Untitled',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((d['description'] as String?)?.isNotEmpty ==
                              true) ...[
                            const SizedBox(height: 4),
                            Text(
                              d['description'] as String,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          if ((d['stakes'] as String?)?.isNotEmpty == true ||
                              (d['category'] as String?)?.isNotEmpty ==
                                  true)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Wrap(
                                spacing: 6,
                                children: [
                                  if ((d['category'] as String?)
                                          ?.isNotEmpty ==
                                      true)
                                    _SmallChip(
                                        label: d['category'] as String),
                                  if ((d['stakes'] as String?)?.isNotEmpty ==
                                      true)
                                    _SmallChip(
                                        label: d['stakes'] as String),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),

                // ── Error message ───────────────────────────────────────
                if (_errorMessage != null)
                  Card(
                    color: AppColors.destructive.withValues(alpha: 0.08),
                    margin: const EdgeInsets.only(top: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _errorMessage!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.destructive),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Create button ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (selectedCount == 0 || _isCreating)
                    ? null
                    : _createSelected,
                child: _isCreating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text('Creating decisions...'),
                        ],
                      )
                    : Text(
                        'Create $selectedCount '
                        'decision${selectedCount == 1 ? '' : 's'}',
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Main capture step ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_inReviewMode) return _buildReviewStep(context);

    final wordCount = _wordCount;
    final hasEnoughWords = wordCount >= 100;

    return Scaffold(
      appBar: AppHeader(
        title: 'Capture from Meeting',
        automaticallyImplyLeading: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Instruction card ────────────────────────────────────────────
          Card(
            color: Theme.of(context).colorScheme.surface,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    size: 20,
                    color: Colors.teal,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Paste your meeting notes and AI will extract the '
                      'key decision, description, stakes, and category for you.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Notes text field ─────────────────────────────────────────────
          Card(
            color: Theme.of(context).colorScheme.surface,
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _notesController,
                minLines: 8,
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: 'Paste your meeting notes here...',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),

          // ── Word count hint ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Text(
              wordCount == 0
                  ? 'Works best with 100+ words'
                  : hasEnoughWords
                      ? '$wordCount words — ready to extract'
                      : '$wordCount words — works best with 100+',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: hasEnoughWords
                        ? AppColors.success
                        : AppColors.textMuted,
                  ),
            ),
          ),

          // ── Error message ────────────────────────────────────────────────
          if (_errorMessage != null) ...[
            Card(
              color: AppColors.destructive.withValues(alpha: 0.08),
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 18,
                          color: AppColors.destructive,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.destructive),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _fillManually,
                      child: const Text('Fill in manually instead'),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Extract button ───────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_isExtracting || _notesController.text.trim().isEmpty)
                  ? null
                  : _extract,
              child: _isExtracting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text('Analysing meeting notes...'),
                      ],
                    )
                  : const Text('Extract Decision'),
            ),
          ),

          const SizedBox(height: 12),

          // ── Manual fallback ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _fillManually,
              child: const Text('Fill in manually'),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Small chip for review step metadata ───────────────────────────────────────

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
      ),
    );
  }
}
