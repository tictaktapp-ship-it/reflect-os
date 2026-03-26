import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/providers/draft_persistence_provider.dart';
import 'package:reflect_os/core/providers/workspace_ai_provider.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/decisions/data/models/create_decision_input.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';
import 'package:reflect_os/features/settings/providers/vertical_provider.dart';
import 'package:reflect_os/features/tags/data/models/tag.dart';
import 'package:reflect_os/features/tags/providers/tags_provider.dart';
import 'package:reflect_os/features/templates/data/models/decision_template.dart';
import 'package:reflect_os/features/templates/screens/templates_screen.dart';
import 'package:reflect_os/widgets/dialog_shell.dart';
import 'package:reflect_os/core/theme/app_radius.dart';

class CreateDecisionScreen extends ConsumerStatefulWidget {
  const CreateDecisionScreen({
    super.key,
    this.initialTemplate,
    this.meetingCapture,
  });

  final DecisionTemplate? initialTemplate;

  /// Pre-filled fields from meeting-note extraction.
  /// Keys: title, description, stakes, category (all String?), fromMeeting (bool).
  final Map<String, dynamic>? meetingCapture;

  @override
  ConsumerState<CreateDecisionScreen> createState() =>
      _CreateDecisionScreenState();
}

class _CreateDecisionScreenState extends ConsumerState<CreateDecisionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // ── Category / stakes / visibility ───────────────────────────────────────
  String? _categoryId;
  String? _stakes;
  String _visibility = 'workspace';

  // ── Approval / continuous ─────────────────────────────────────────────────
  bool _requiresApproval = false;
  bool _isContinuous = false;

  // ── Initial confidence (FIX 2: always visible, no toggle) ────────────────
  int _confidence = 5;

  // ── Deadline (FIX 3: + notification fields) ───────────────────────────────
  DateTime? _deadline;
  bool _deadlineNotificationEnabled = false;
  int? _deadlineNotificationOffsetDays; // null = on the day

  // ── Tags (FIX 1: custom autocomplete) ────────────────────────────────────
  final _tagInputController = TextEditingController();
  final _tagInputFocus = FocusNode();
  List<Tag> _selectedTags = [];
  List<Tag> _tagSuggestions = [];
  bool _tagDropdownVisible = false;
  Timer? _tagDebounce;

  // ── Auto-save ─────────────────────────────────────────────────────────────
  late final String _draftId;
  bool _isSavedAsDraft = false;
  Timer? _autoSaveTimer;
  String _autoSaveStatus = ''; // '', 'saving', 'saved'

  // ── Template / meeting banner ─────────────────────────────────────────────
  bool _isSubmitting = false;
  DecisionTemplate? _appliedTemplate;
  String? _projectedOutcome;
  bool _showMeetingBanner = false;
  String? _meetingCategoryName;

  @override
  void initState() {
    super.initState();
    _draftId = _generateUuid();
    _titleController.addListener(_scheduleAutoSave);
    _descriptionController.addListener(_scheduleAutoSave);
    final t = widget.initialTemplate;
    if (t != null) {
      _appliedTemplate = t;
      if (t.defaultStakes != null) _stakes = t.defaultStakes;
      _requiresApproval = t.requiresApproval;
    }
    final mc = widget.meetingCapture;
    if (mc != null && mc['fromMeeting'] == true) {
      _titleController.text = mc['title'] as String? ?? '';
      _descriptionController.text = mc['description'] as String? ?? '';
      final stakes = mc['stakes'] as String?;
      if (stakes != null) _stakes = stakes;
      _meetingCategoryName = mc['category'] as String?;
      _showMeetingBanner = true;
    }
    _tagInputFocus.addListener(_onTagFocusChange);
  }

  void _onTagFocusChange() {
    if (_tagInputFocus.hasFocus) {
      setState(() => _tagDropdownVisible = true);
      if (_tagInputController.text.isEmpty) _loadRecentTags();
    } else {
      // Delay hiding so taps on suggestions register first.
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_tagInputFocus.hasFocus) {
          setState(() => _tagDropdownVisible = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.removeListener(_scheduleAutoSave);
    _descriptionController.removeListener(_scheduleAutoSave);
    _titleController.dispose();
    _descriptionController.dispose();
    _tagInputController.dispose();
    _tagInputFocus.removeListener(_onTagFocusChange);
    _tagInputFocus.dispose();
    _tagDebounce?.cancel();
    super.dispose();
  }

  // ── UUID helper ───────────────────────────────────────────────────────────

  static String _generateUuid() {
    final rng = Random.secure();
    final b = List<int>.generate(16, (_) => rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String hex(int n) => n.toRadixString(16).padLeft(2, '0');
    return '${b.sublist(0, 4).map(hex).join()}'
        '-${b.sublist(4, 6).map(hex).join()}'
        '-${b.sublist(6, 8).map(hex).join()}'
        '-${b.sublist(8, 10).map(hex).join()}'
        '-${b.sublist(10, 16).map(hex).join()}';
  }

  // ── Auto-save helpers ─────────────────────────────────────────────────────

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      if (mounted && _autoSaveStatus.isNotEmpty) {
        setState(() => _autoSaveStatus = '');
      }
      return;
    }
    if (mounted && _autoSaveStatus != 'saving') {
      setState(() => _autoSaveStatus = 'saving');
    }
    _autoSaveTimer = Timer(const Duration(seconds: 2), _autoSave);
  }

  Future<void> _autoSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || !mounted) return;
    try {
      final workspaceId = ref.read(currentWorkspaceProvider).valueOrNull;
      if (workspaceId == null) return;
      final description = _descriptionController.text.trim();
      await ref.read(decisionsRepositoryProvider).autoSaveDraft(
            id: _draftId,
            workspaceId: workspaceId,
            title: title,
            description: description.isEmpty ? null : description,
            categoryId: _categoryId,
            stakes: _stakes,
            initialConfidence: _confidence,
            isContinuous: _isContinuous,
            visibility: _visibility,
            requiresApproval: _requiresApproval,
          );
      if (mounted) {
        setState(() {
          _isSavedAsDraft = true;
          _autoSaveStatus = 'saved';
        });
      }
    } catch (_) {
      if (mounted && _autoSaveStatus == 'saving') {
        setState(() => _autoSaveStatus = '');
      }
    }
  }

  // ── Tag helpers ───────────────────────────────────────────────────────────

  Future<void> _loadRecentTags() async {
    final workspaceId = ref.read(currentWorkspaceProvider).valueOrNull;
    if (workspaceId == null) return;
    try {
      final tags = await ref
          .read(tagsRepositoryProvider)
          .getRecentTags(workspaceId);
      if (mounted) setState(() => _tagSuggestions = tags);
    } catch (_) {}
  }

  void _onTagInputChanged(String query) {
    _tagDebounce?.cancel();
    if (query.trim().isEmpty) {
      _loadRecentTags();
      return;
    }
    _tagDebounce = Timer(const Duration(milliseconds: 250), () async {
      final workspaceId = ref.read(currentWorkspaceProvider).valueOrNull;
      if (workspaceId == null || !mounted) return;
      try {
        final tags = await ref
            .read(tagsRepositoryProvider)
            .searchTags(workspaceId, query.trim());
        if (mounted) setState(() => _tagSuggestions = tags);
      } catch (_) {}
    });
  }

  void _addTag(Tag tag) {
    setState(() {
      if (!_selectedTags.any((t) => t.id == tag.id)) {
        _selectedTags.add(tag);
      }
      _tagSuggestions = [];
      _tagDropdownVisible = true;
    });
    _tagInputController.clear();
    _tagInputFocus.requestFocus();
    _loadRecentTags();
  }

  Future<void> _createAndAddTag(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final workspaceId = ref.read(currentWorkspaceProvider).valueOrNull;
    if (workspaceId == null) return;
    try {
      final tag = await ref
          .read(tagsRepositoryProvider)
          .createTag(workspaceId, trimmed);
      if (mounted) {
        _addTag(tag);
        ref.invalidate(workspaceTagsProvider);
      }
    } catch (e) {
      _showError('Failed to create tag: $e');
    }
  }

  void _onTagSubmitted(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final existing = _tagSuggestions
        .where((t) => t.name.toLowerCase() == trimmed.toLowerCase())
        .firstOrNull;
    if (existing != null) {
      _addTag(existing);
    } else {
      _createAndAddTag(trimmed);
    }
  }

  // ── Template ──────────────────────────────────────────────────────────────

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

  // ── Meeting import ────────────────────────────────────────────────────────

  void _onImportFromMeetingNotes() {
    showDialog<void>(
      context: context,
      builder: (ctx) => DialogShell(
        title: 'AI data notice',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.smart_toy_outlined,
                    color: Color(0xFF19CBD6), size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'This tool uses AI to extract decisions from your '
                    'meeting notes.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Before continuing, please confirm:',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569)),
            ),
            const SizedBox(height: 8),
            _consentBullet(
                'Your meeting notes will be sent to an AI service for '
                'processing'),
            _consentBullet(
                'Do not include highly confidential, personally identifiable, '
                'or legally sensitive information'),
            _consentBullet(
                "By continuing, you confirm you are authorised to share this "
                "content with an external AI service under your organisation's "
                "data policy"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _navigateToCaptureFromMeeting();
            },
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF19CBD6)),
            child: const Text('I understand, continue'),
          ),
        ],
      ),
    );
  }

  Widget _consentBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(
                  color: Color(0xFF19CBD6),
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF475569))),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToCaptureFromMeeting() async {
    final result = await context.push<Map<String, dynamic>>(
      Routes.decisionsMeetingCapture,
      extra: <String, dynamic>{'mode': 'multiple', 'source': 'add_decision'},
    );
    if (result != null && mounted) {
      setState(() {
        _titleController.text = result['title'] as String? ?? '';
        _descriptionController.text = result['description'] as String? ?? '';
        final stakes = result['stakes'] as String?;
        if (stakes != null) _stakes = stakes;
        _meetingCategoryName = result['category'] as String?;
        _showMeetingBanner = true;
      });
    }
  }

  Future<void> _openToolkitForProjectedOutcome() async {
    final result = await context.push<String>(Routes.toolkitPicker);
    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _projectedOutcome = result);
    }
  }

  // ── Deadline ──────────────────────────────────────────────────────────────

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
      _scheduleAutoSave();
    }
  }

  void _clearDeadline() {
    setState(() {
      _deadline = null;
      _deadlineNotificationEnabled = false;
      _deadlineNotificationOffsetDays = null;
    });
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    _autoSaveTimer?.cancel();
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
        initialConfidence: _confidence,
        descriptionEncrypted: description.isEmpty ? null : description,
        decisionDeadline: _isContinuous ? null : _deadline,
        isContinuous: _isContinuous,
        visibility: _visibility,
        requiresApproval: _requiresApproval,
        projectedOutcome: _projectedOutcome,
        deadlineNotificationEnabled:
            _isContinuous ? false : _deadlineNotificationEnabled,
        deadlineNotificationOffsetDays:
            _isContinuous ? null : _deadlineNotificationOffsetDays,
      );

      final id = await ref
          .read(decisionsRepositoryProvider)
          .createDecision(input, existingId: _isSavedAsDraft ? _draftId : null);

      // Save selected tags.
      if (_selectedTags.isNotEmpty) {
        final tagsRepo = ref.read(tagsRepositoryProvider);
        for (final tag in _selectedTags) {
          await tagsRepo.addTagToDecision(id, tag.id);
        }
      }

      // Upsert deadline notification queue entry if enabled.
      if (!_isContinuous &&
          _deadline != null &&
          _deadlineNotificationEnabled) {
        final offsetDays = _deadlineNotificationOffsetDays;
        final scheduledDate = offsetDays != null
            ? _deadline!.subtract(Duration(days: offsetDays))
            : _deadline!;
        final scheduledFor = DateTime.utc(
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day,
          9,
          0,
          0,
        );
        final userId = supabase.auth.currentUser!.id;
        await supabase.from('notification_queue').upsert(
          {
            'workspace_id': workspaceId,
            'user_id': userId,
            'type': 'deadline_reminder',
            'related_entity_type': 'decision',
            'related_entity_id': id,
            'scheduled_for': scheduledFor.toIso8601String(),
            'status': 'Pending',
            'dedupe_key': 'deadline_reminder_$id',
          },
          onConflict: 'dedupe_key',
        );
      }

      // Clean up any locally persisted draft for this id.
      await ref.read(draftPersistenceServiceProvider).deleteDraft(id);

      ref.invalidate(decisionsProvider);

      if (mounted) {
        context.go('/decisions/detail/$id');
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final verticalAsync = ref.watch(currentVerticalProvider);
    final vertical = verticalAsync.valueOrNull;
    final suggestedCategoryNames = vertical?.suggestedCategories ?? [];
    final aiEnabled =
        ref.watch(workspaceAiEnabledProvider).valueOrNull ?? true;

    // Resolve meeting-extracted category name → ID once categories load.
    if (_meetingCategoryName != null && _categoryId == null) {
      ref.listen(categoriesProvider, (_, next) {
        if (next.hasValue &&
            _meetingCategoryName != null &&
            _categoryId == null) {
          final match = next.value
              ?.where((c) =>
                  c.name.toLowerCase() == _meetingCategoryName!.toLowerCase())
              .firstOrNull;
          if (match != null) setState(() => _categoryId = match.id);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          width: 28,
          height: 28,
          child: SvgPicture.asset('assets/branding/icon.svg'),
        ),
        actions: [
          if (_autoSaveStatus.isNotEmpty)
            AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 300),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    _autoSaveStatus == 'saving' ? 'Saving…' : 'Draft saved',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),
              ),
            ),
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
            // ── Meeting capture banner ──────────────────────────────
            if (_showMeetingBanner)
              Dismissible(
                key: const ValueKey('meeting-banner'),
                direction: DismissDirection.horizontal,
                onDismissed: (_) =>
                    setState(() => _showMeetingBanner = false),
                child: Card(
                  color: Colors.teal.withValues(alpha: 0.1),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.smBR,
                    side: BorderSide(
                        color: Colors.teal.withValues(alpha: 0.3)),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.auto_awesome_outlined,
                        color: Colors.teal, size: 18),
                    title: const Text('Pre-filled from meeting notes',
                        style: TextStyle(fontSize: 13)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () =>
                          setState(() => _showMeetingBanner = false),
                    ),
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),

            // ── Template / import ───────────────────────────────────
            _SectionCard(
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (_appliedTemplate == null)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.article_outlined, size: 18),
                        label: const Text('Use a template'),
                        onPressed: _showTemplatePicker,
                      )
                    else
                      Chip(
                        avatar:
                            const Icon(Icons.article_outlined, size: 16),
                        label:
                            Text('Template: ${_appliedTemplate!.name}'),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: _clearTemplate,
                      ),
                    if (aiEnabled)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.mic_outlined,
                            color: Color(0xFF19CBD6), size: 18),
                        label: const Text('Import from meeting notes'),
                        onPressed: _onImportFromMeetingNotes,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF19CBD6),
                          side: const BorderSide(
                              color: Color(0xFF19CBD6), width: 1.5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.smBR),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'AI disabled for this workspace',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // ── Title ───────────────────────────────────────────────
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

            // ── Category & Stakes ────────────────────────────────────
            _SectionCard(
              children: [
                categoriesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                  error: (e, st) => const SizedBox.shrink(),
                  data: (categories) {
                    final sorted = [...categories]..sort((a, b) {
                        final aIdx = suggestedCategoryNames.indexWhere(
                            (s) => s.toLowerCase() == a.name.toLowerCase());
                        final bIdx = suggestedCategoryNames.indexWhere(
                            (s) => s.toLowerCase() == b.name.toLowerCase());
                        if (aIdx != -1 && bIdx == -1) return -1;
                        if (aIdx == -1 && bIdx != -1) return 1;
                        return a.name.compareTo(b.name);
                      });
                    return DropdownButtonFormField<String>(
                      initialValue: _categoryId,
                      decoration:
                          const InputDecoration(labelText: 'Category'),
                      hint: const Text('Select a category'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('None')),
                        ...sorted.map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _categoryId = value);
                        _scheduleAutoSave();
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(_stakes),
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
                  onChanged: (value) {
                    setState(() => _stakes = value);
                    _scheduleAutoSave();
                  },
                ),
              ],
            ),

            // ── Tags (FIX 1: custom autocomplete) ───────────────────
            _SectionCard(
              children: [
                Text(
                  'Tags',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),

                // Tag text input
                TextField(
                  controller: _tagInputController,
                  focusNode: _tagInputFocus,
                  decoration: InputDecoration(
                    hintText: 'Add a tag…',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: _tagInputController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () {
                              _tagInputController.clear();
                              setState(() => _tagSuggestions = []);
                              _loadRecentTags();
                            },
                          )
                        : null,
                  ),
                  onChanged: _onTagInputChanged,
                  onSubmitted: _onTagSubmitted,
                ),

                // Selected tag chips — always rendered, teal styling
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _selectedTags
                      .map((tag) => Chip(
                            label: Text(tag.name),
                            deleteIcon:
                                const Icon(Icons.close, size: 14),
                            onDeleted: () =>
                                setState(() => _selectedTags.remove(tag)),
                            backgroundColor: const Color(0xFF19CBD6)
                                .withValues(alpha: 0.12),
                            side: const BorderSide(
                                color: Color(0xFF19CBD6)),
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),

                // Suggestions dropdown
                if (_tagDropdownVisible &&
                    (_tagSuggestions.isNotEmpty ||
                        _tagInputController.text.isNotEmpty))
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.smBR,
                      border: Border.all(
                          color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Matching existing tags (excluding already selected)
                        ..._tagSuggestions
                            .where((t) => !_selectedTags
                                .any((s) => s.id == t.id))
                            .map(
                              (tag) => InkWell(
                                onTap: () => _addTag(tag),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      const Icon(
                                          Icons.label_outline,
                                          size: 16,
                                          color: Color(0xFF94A3B8)),
                                      const SizedBox(width: 8),
                                      Text(tag.name,
                                          style: const TextStyle(
                                              fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                        // "Create" option if no exact match
                        if (_tagInputController.text.trim().isNotEmpty &&
                            !_tagSuggestions.any((t) =>
                                t.name.toLowerCase() ==
                                _tagInputController.text
                                    .trim()
                                    .toLowerCase()))
                          InkWell(
                            onTap: () => _createAndAddTag(
                                _tagInputController.text),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.add,
                                      size: 16,
                                      color: Color(0xFF19CBD6)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Create "${_tagInputController.text.trim()}"',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF19CBD6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),

            // ── Initial Confidence (FIX 2: always visible, no toggle) ──
            _SectionCard(
              children: [
                Text(
                  'Initial Confidence',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),
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
                        onChanged: (value) {
                          setState(() => _confidence = value.round());
                          _scheduleAutoSave();
                        },
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

                const SizedBox(height: 8),
                // ── Projected outcome attachment ──────────────────
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        size: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      'Projected outcome',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                    const Spacer(),
                    if (_projectedOutcome != null)
                      Flexible(
                        child: GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => DialogShell(
                                title: 'Projected outcome',
                                child: SizedBox(
                                  width: double.maxFinite,
                                  child: Text(
                                    _projectedOutcome!,
                                    style: Theme.of(ctx)
                                        .textTheme
                                        .bodyMedium,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      await context.push(
                                        Routes.toolkitPicker,
                                        extra: {
                                          'pickerMode': false,
                                          'readOnlyResult':
                                              _projectedOutcome,
                                        },
                                      );
                                    },
                                    child: const Text(
                                        'View full details'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _openToolkitForProjectedOutcome();
                                    },
                                    child: const Text('Change'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Text(
                            _projectedOutcome!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                  decoration:
                                      TextDecoration.underline,
                                ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(
                          _projectedOutcome == null
                              ? Icons.add
                              : Icons.edit,
                          size: 14),
                      label: Text(_projectedOutcome == null
                          ? 'Add from toolkit'
                          : 'Change'),
                      onPressed: _openToolkitForProjectedOutcome,
                    ),
                  ],
                ),
              ],
            ),

            // ── Description ──────────────────────────────────────────
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

            // ── Deadline (FIX 3: + notification opt-in) ─────────────
            _SectionCard(
              children: [
                Opacity(
                  // Grey out when continuous — continuous decisions have
                  // no fixed end date.
                  opacity: _isContinuous ? 0.4 : 1.0,
                  child: IgnorePointer(
                    ignoring: _isContinuous,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Decision Deadline',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                            color: AppColors
                                                .textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _deadline != null
                                        ? DateFormat('d MMM yyyy')
                                            .format(_deadline!)
                                        : 'No deadline set',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            if (_deadline != null)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                tooltip: 'Clear deadline',
                                onPressed: _clearDeadline,
                              ),
                            IconButton(
                              icon: const Icon(
                                  Icons.calendar_today_outlined),
                              tooltip: 'Pick date',
                              onPressed: _pickDeadline,
                            ),
                          ],
                        ),

                        // Notification opt-in (FIX 3)
                        if (_deadline != null) ...[
                          const Divider(height: 20),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: const Icon(
                                Icons.notifications_outlined,
                                size: 20),
                            title: const Text(
                                'Notify me about this deadline'),
                            value: _deadlineNotificationEnabled,
                            onChanged: (v) => setState(() {
                              _deadlineNotificationEnabled = v;
                              if (!v)
                                _deadlineNotificationOffsetDays =
                                    null;
                            }),
                          ),
                          if (_deadlineNotificationEnabled) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Text('Remind me:',
                                    style: TextStyle(fontSize: 13)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<int?>(
                                    value:
                                        _deadlineNotificationOffsetDays,
                                    decoration:
                                        const InputDecoration(
                                            isDense: true),
                                    items: const [
                                      DropdownMenuItem(
                                          value: null,
                                          child: Text(
                                              'On the deadline day')),
                                      DropdownMenuItem(
                                          value: 1,
                                          child:
                                              Text('1 day before')),
                                      DropdownMenuItem(
                                          value: 3,
                                          child:
                                              Text('3 days before')),
                                      DropdownMenuItem(
                                          value: 7,
                                          child:
                                              Text('7 days before')),
                                      DropdownMenuItem(
                                          value: 14,
                                          child: Text(
                                              '14 days before')),
                                    ],
                                    onChanged: (v) => setState(() =>
                                        _deadlineNotificationOffsetDays =
                                            v),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Visibility, Continuous & Requires Approval ───────────
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
                    ButtonSegment(
                        value: 'workspace', label: Text('Workspace')),
                    ButtonSegment(
                        value: 'stakeholders_only',
                        label: Text('Stakeholders Only')),
                  ],
                  selected: {_visibility},
                  onSelectionChanged: (selection) {
                    setState(() => _visibility = selection.first);
                    _scheduleAutoSave();
                  },
                ),
                const SizedBox(height: 16),

                // Continuous (FIX 4: updated helper text)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Continuous Decision'),
                  subtitle: Text(
                    'This is a standing decision with no fixed end date',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                  ),
                  value: _isContinuous,
                  onChanged: (value) {
                    setState(() {
                      _isContinuous = value;
                      // Continuous decisions have no deadline.
                      if (value) {
                        _deadline = null;
                        _deadlineNotificationEnabled = false;
                        _deadlineNotificationOffsetDays = null;
                      }
                    });
                    _scheduleAutoSave();
                  },
                ),

                // Requires approval (FIX 4: updated helper text)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Requires Approval'),
                  subtitle: Text(
                    'Another team member must approve before activating',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                  ),
                  value: _requiresApproval,
                  onChanged: (value) {
                    setState(() => _requiresApproval = value);
                    _scheduleAutoSave();
                  },
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
