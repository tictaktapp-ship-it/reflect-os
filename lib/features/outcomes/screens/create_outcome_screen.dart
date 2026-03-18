import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/features/decisions/data/confidence_triggers_service.dart';
import 'package:reflect_os/features/outcomes/providers/outcomes_provider.dart';

class CreateOutcomeScreen extends ConsumerStatefulWidget {
  const CreateOutcomeScreen({required this.decisionId, super.key});

  final String decisionId;

  @override
  ConsumerState<CreateOutcomeScreen> createState() =>
      _CreateOutcomeScreenState();
}

class _CreateOutcomeScreenState extends ConsumerState<CreateOutcomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _outcomeTextController = TextEditingController();
  final _lessonsLearnedController = TextEditingController();

  int _qualityScore = 5;
  String? _outcomeState;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _outcomeTextController.dispose();
    _lessonsLearnedController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final outcomeText = _outcomeTextController.text.trim();
      final lessonsLearned = _lessonsLearnedController.text.trim();

      await ref.read(outcomesRepositoryProvider).saveOutcomeUpdate(
            decisionId: widget.decisionId,
            qualityScore: _qualityScore,
            outcomeText: outcomeText.isEmpty ? null : outcomeText,
            outcomeState: _outcomeState,
            lessonsLearned: lessonsLearned.isEmpty ? null : lessonsLearned,
          );

      ref.invalidate(outcomesProvider(widget.decisionId));

      // Forward-write confidence triggers for this new outcome review.
      // Non-fatal: the lens backfill will catch any missed triggers on next view.
      unawaited(
        const ConfidenceTriggersService().inferForDecision(widget.decisionId),
      );

      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save outcome: $e'),
          backgroundColor: AppColors.destructive,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Outcome'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Quality Score ───────────────────────────────────────
            _SectionCard(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Quality Score *',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                      ),
                    ),
                    Text(
                      '$_qualityScore / 10',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                Slider(
                  value: _qualityScore.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '$_qualityScore / 10',
                  onChanged: (value) =>
                      setState(() => _qualityScore = value.round()),
                ),
              ],
            ),

            // ── Outcome State ───────────────────────────────────────
            _SectionCard(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _outcomeState,
                  decoration:
                      const InputDecoration(labelText: 'Outcome State'),
                  hint: const Text('Select state'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('None')),
                    DropdownMenuItem(
                        value: 'Unrealised', child: Text('Unrealised')),
                    DropdownMenuItem(
                        value: 'Partial', child: Text('Partial')),
                    DropdownMenuItem(
                        value: 'Realised', child: Text('Realised')),
                    DropdownMenuItem(
                        value: 'Written_off', child: Text('Written Off')),
                  ],
                  onChanged: (value) => setState(() => _outcomeState = value),
                ),
              ],
            ),

            // ── Outcome Text ────────────────────────────────────────
            _SectionCard(
              children: [
                TextFormField(
                  controller: _outcomeTextController,
                  decoration: const InputDecoration(
                    labelText: 'Outcome',
                    hintText: 'What actually happened?',
                    alignLabelWithHint: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 5,
                  minLines: 3,
                ),
              ],
            ),

            // ── Lessons Learned ─────────────────────────────────────
            _SectionCard(
              children: [
                TextFormField(
                  controller: _lessonsLearnedController,
                  decoration: const InputDecoration(
                    labelText: 'Lessons Learned',
                    hintText: 'What would you do differently?',
                    alignLabelWithHint: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 5,
                  minLines: 3,
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}
