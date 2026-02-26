import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/providers/draft_persistence_provider.dart';
import 'package:reflect_os/features/decisions/data/models/create_decision_input.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';
import 'package:reflect_os/features/templates/data/models/decision_template.dart';
import 'package:reflect_os/features/templates/screens/templates_screen.dart';

class CreateDecisionScreen extends ConsumerStatefulWidget {
  const CreateDecisionScreen({super.key, this.initialTemplate});

  final DecisionTemplate? initialTemplate;

  @override
  ConsumerState<CreateDecisionScreen> createState() =>
      _CreateDecisionScreenState();
}

class _CreateDecisionScreenState extends ConsumerState<CreateDecisionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _categoryId;
  String? _stakes;
  bool _requiresApproval = false;
  bool _useConfidence = false;
  int _confidence = 5;
  DateTime? _deadline;
  String _visibility = 'workspace';
  bool _isContinuous = false;
  bool _isSubmitting = false;
  DecisionTemplate? _appliedTemplate;

  @override
  void initState() {
    super.initState();
    final t = widget.initialTemplate;
    if (t != null) {
      _appliedTemplate = t;
      if (t.defaultStakes != null) _stakes = t.defaultStakes;
      _requiresApproval = t.requiresApproval;
    }
  }

  void _applyTemplate(DecisionTemplate template) {
    setState(() {
      _appliedTemplate = template;
      if (template.defaultStakes != null) _stakes = template.defaultStakes;
      _requiresApproval = template.requiresApproval;
    });
  }

  void _clearTemplate() {
    setState(() {
      _appliedTemplate = null;
      _stakes = null;
      _requiresApproval = false;
    });
  }

  Future<void> _showTemplatePicker() async {
    final template = await showTemplatePicker(context, ref);
    if (template != null) _applyTemplate(template);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final workspaceId = await ref.read(currentWorkspaceProvider.future);
      if (workspaceId == null) {
        _showError('No workspace found. Please contact support.');
        return;
      }

      final description = _descriptionController.text.trim();
      final input = CreateDecisionInput(
        workspaceId: workspaceId,
        title: _titleController.text.trim(),
        categoryId: _categoryId,
        stakes: _stakes,
        initialConfidence: _useConfidence ? _confidence : null,
        descriptionEncrypted: description.isEmpty ? null : description,
        decisionDeadline: _deadline,
        isContinuous: _isContinuous,
        visibility: _visibility,
      );

      final id = await ref
          .read(decisionsRepositoryProvider)
          .createDecision(input);

      // Clean up any locally persisted draft for this id.
      await ref.read(draftPersistenceServiceProvider).deleteDraft(id);

      ref.invalidate(decisionsProvider);

      if (mounted) {
        context.pop();
        context.push('/decisions/detail/$id');
      }
    } catch (e) {
      _showError('Failed to create decision: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.destructive,
      ),
    );
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SvgPicture.asset(
              Theme.of(context).brightness == Brightness.dark
                  ? 'assets/images/reflect-icon-dark.svg'
                  : 'assets/images/reflect-icon-light.svg',
              height: 40,
            ),
            const SizedBox(width: 8),
            const Text('New Decision'),
          ],
        ),
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
            // ── Template ───────────────────────────────────────────
            _SectionCard(
              children: [
                if (_appliedTemplate == null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.article_outlined, size: 18),
                    label: const Text('Use a template'),
                    onPressed: _showTemplatePicker,
                  )
                else
                  Chip(
                    avatar: const Icon(Icons.article_outlined, size: 16),
                    label: Text('Template: ${_appliedTemplate!.name}'),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: _clearTemplate,
                  ),
              ],
            ),

            // ── Title ──────────────────────────────────────────────
            _SectionCard(
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    hintText: 'What decision are you making?',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Title is required'
                          : null,
                ),
              ],
            ),

            // ── Category & Stakes ───────────────────────────────────
            _SectionCard(
              children: [
                categoriesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                  error: (e, st) => const SizedBox.shrink(),
                  data: (categories) => DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    hint: const Text('Select a category'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('None'),
                      ),
                      ...categories.map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _categoryId = value),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(_stakes),
                  initialValue: _stakes,
                  decoration: const InputDecoration(labelText: 'Stakes'),
                  hint: const Text('Select stakes'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('None')),
                    DropdownMenuItem(value: 'Low', child: Text('Low')),
                    DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'High', child: Text('High')),
                    DropdownMenuItem(value: 'Critical', child: Text('Critical')),
                  ],
                  onChanged: (value) => setState(() => _stakes = value),
                ),
              ],
            ),

            // ── Initial Confidence ──────────────────────────────────
            _SectionCard(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Initial Confidence',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                      ),
                    ),
                    Switch(
                      value: _useConfidence,
                      onChanged: (value) =>
                          setState(() => _useConfidence = value),
                    ),
                  ],
                ),
                if (_useConfidence) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _confidence.toDouble(),
                          min: 1,
                          max: 10,
                          divisions: 9,
                          label: '$_confidence / 10',
                          onChanged: (value) =>
                              setState(() => _confidence = value.round()),
                        ),
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(
                          '$_confidence / 10',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),

            // ── Description ─────────────────────────────────────────
            _SectionCard(
              children: [
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Context, reasoning, key considerations...',
                    alignLabelWithHint: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 5,
                  minLines: 3,
                ),
              ],
            ),

            // ── Deadline ────────────────────────────────────────────
            _SectionCard(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Decision Deadline',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _deadline != null
                                ? DateFormat('d MMM yyyy').format(_deadline!)
                                : 'No deadline set',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    if (_deadline != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear deadline',
                        onPressed: () => setState(() => _deadline = null),
                      ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today_outlined),
                      tooltip: 'Pick date',
                      onPressed: _pickDeadline,
                    ),
                  ],
                ),
              ],
            ),

            // ── Visibility & Continuous ─────────────────────────────
            _SectionCard(
              children: [
                Text(
                  'Visibility',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'workspace', label: Text('Workspace')),
                    ButtonSegment(
                        value: 'stakeholders_only',
                        label: Text('Stakeholders Only')),
                  ],
                  selected: {_visibility},
                  onSelectionChanged: (selection) =>
                      setState(() => _visibility = selection.first),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Continuous Decision'),
                  subtitle: Text(
                    'An ongoing process rather than a one-time choice',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                  ),
                  value: _isContinuous,
                  onChanged: (value) =>
                      setState(() => _isContinuous = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Requires Approval'),
                  subtitle: Text(
                    'Workspace admin must approve before this decision is published',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                  ),
                  value: _requiresApproval,
                  onChanged: (value) =>
                      setState(() => _requiresApproval = value),
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
