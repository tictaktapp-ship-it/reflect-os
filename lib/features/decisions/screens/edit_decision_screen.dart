import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/decisions/data/models/category.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';
import 'package:reflect_os/widgets/dialog_shell.dart';

enum _ConflictChoice { keepMine, discard }

class EditDecisionScreen extends ConsumerStatefulWidget {
  const EditDecisionScreen({required this.decision, super.key});

  final Decision decision;

  @override
  ConsumerState<EditDecisionScreen> createState() =>
      _EditDecisionScreenState();
}

class _EditDecisionScreenState extends ConsumerState<EditDecisionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Category is matched by name (view exposes name, not id).
  String? _categoryId;
  String? _initialCategoryId;
  bool _categoryInitialized = false;

  String? _stakes;
  bool _useConfidence = false;
  int _confidence = 5;
  DateTime? _deadline;
  // visibility_mode and continuous are not exposed by user_visible_decisions.
  // They default to 'workspace' and false and are always included in the update.
  String _visibility = 'workspace';
  bool _isContinuous = false;
  bool _requiresApproval = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final d = widget.decision;
    _titleController.text = d.title;
    _descriptionController.text = d.descriptionEncrypted ?? '';
    _stakes = d.stakes;
    if (d.initialConfidence != null) {
      _useConfidence = true;
      _confidence = d.initialConfidence!;
    }
    _deadline = d.decisionDeadline;
    _requiresApproval = d.requiresApproval;
    // Category resolved post-frame once categories are available.
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryInitCategory());
  }

  void _tryInitCategory() {
    if (_categoryInitialized || !mounted) return;
    final cats = ref.read(categoriesProvider).valueOrNull;
    if (cats != null) _doInitCategory(cats);
  }

  void _doInitCategory(List<Category> cats) {
    _categoryInitialized = true;
    if (widget.decision.categoryName == null) return;
    final matching =
        cats.where((c) => c.name == widget.decision.categoryName).toList();
    if (matching.isNotEmpty && mounted) {
      setState(() {
        _categoryId = matching.first.id;
        _initialCategoryId = matching.first.id;
      });
    }
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
      final d = widget.decision;
      final fields = <String, dynamic>{};

      // Title — always included (required field).
      fields['title'] = _titleController.text.trim();

      // Category — include only if changed.
      if (_categoryId != _initialCategoryId) {
        fields['category_id'] = _categoryId;
      }

      // Stakes.
      if (_stakes != d.stakes) fields['stakes'] = _stakes;

      // Confidence.
      final newConf = _useConfidence ? _confidence : null;
      if (newConf != d.initialConfidence) fields['initial_confidence'] = newConf;

      // Description.
      final desc = _descriptionController.text.trim();
      final descOrNull = desc.isEmpty ? null : desc;
      if (descOrNull != d.descriptionEncrypted) {
        fields['description_encrypted'] = descOrNull;
      }

      // Deadline — compare date-only to avoid time-component false positives.
      final origDl = d.decisionDeadline != null
          ? DateTime(d.decisionDeadline!.year, d.decisionDeadline!.month,
              d.decisionDeadline!.day)
          : null;
      final newDl = _deadline != null
          ? DateTime(_deadline!.year, _deadline!.month, _deadline!.day)
          : null;
      if (newDl != origDl) {
        fields['decision_deadline'] = _deadline?.toIso8601String();
      }

      // Visibility, continuous, requires_approval — cannot pre-populate from
      // view; always include.
      fields['visibility_mode'] = _visibility;
      fields['continuous'] = _isContinuous;
      fields['requires_approval'] = _requiresApproval;

      // ── Conflict detection ────────────────────────────────────────
      final serverRow = await supabase
          .from('user_visible_decisions')
          .select('updated_at')
          .eq('id', d.id)
          .maybeSingle();

      if (serverRow != null) {
        final serverUpdatedAt =
            DateTime.parse(serverRow['updated_at'] as String);
        if (serverUpdatedAt.isAfter(d.updatedAt)) {
          if (!mounted) return;
          final choice = await showDialog<_ConflictChoice>(
            context: context,
            builder: (_) => DialogShell(
              title: 'Conflict detected',
              child: const Text(
                'This decision was updated elsewhere since you opened it.\n\nWhat would you like to do?',
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_ConflictChoice.discard),
                  child: const Text('Discard my changes'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_ConflictChoice.keepMine),
                  child: const Text('Keep my changes'),
                ),
              ],
            ),
          );
          if (!mounted) return;
          if (choice == _ConflictChoice.discard) {
            ref.invalidate(decisionDetailProvider(d.id));
            context.pop();
            return;
          }
          // choice == keepMine: fall through to save.
        }
      }

      await ref
          .read(decisionsRepositoryProvider)
          .updateDecision(d.id, fields);

      ref.invalidate(decisionDetailProvider(d.id));
      ref.invalidate(decisionsProvider);

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      // Allow past dates — existing deadline may already be in the past.
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    // Resolve category id once categories first load.
    ref.listen<AsyncValue<List<Category>>>(categoriesProvider, (prev, next) {
      if (!_categoryInitialized && next.hasValue) {
        _doInitCategory(next.value!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SvgPicture.asset(
              Theme.of(context).brightness == Brightness.dark
                  ? 'assets/branding/icon.svg'
                  : 'assets/branding/icon.svg',
              height: 160,
            ),
            const SizedBox(width: 8),
            const Text('Edit Decision'),
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
                    // ValueKey forces a rebuild when _categoryId resolves
                    // async (name→id match), picking up the new initialValue.
                    key: ValueKey(_categoryId),
                    initialValue: _categoryId,
                    decoration:
                        const InputDecoration(labelText: 'Category'),
                    hint: const Text('Select a category'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('None')),
                      ...categories.map(
                        (c) => DropdownMenuItem(
                            value: c.id, child: Text(c.name)),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _categoryId = value),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _stakes,
                  decoration:
                      const InputDecoration(labelText: 'Stakes'),
                  hint: const Text('Select stakes'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('None')),
                    DropdownMenuItem(value: 'Low', child: Text('Low')),
                    DropdownMenuItem(
                        value: 'Medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'High', child: Text('High')),
                    DropdownMenuItem(
                        value: 'Critical', child: Text('Critical')),
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
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
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
                    hintText:
                        'Context, reasoning, key considerations...',
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
                                ?.copyWith(
                                    color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _deadline != null
                                ? DateFormat('d MMM yyyy')
                                    .format(_deadline!)
                                : 'No deadline set',
                            style:
                                Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    if (_deadline != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear deadline',
                        onPressed: () =>
                            setState(() => _deadline = null),
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
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'workspace', label: Text('Workspace')),
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
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
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
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
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
