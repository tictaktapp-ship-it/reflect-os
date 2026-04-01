import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/core/theme/app_radius.dart';
import 'package:reflect_os/features/decisions/data/models/create_decision_input.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';
import 'package:reflect_os/services/activation_sequence_service.dart';

/// Quick Decision Mode — 4-field fast log.
///
/// Designed to work as either:
///   • a modal bottom sheet (mobile — wrap with [showModalBottomSheet])
///   • a centred Dialog child (web/tablet — wrap with [showDialog])
///
/// Callers are responsible for opening/closing via [Navigator.pop].
class QuickLogSheet extends ConsumerStatefulWidget {
  const QuickLogSheet({super.key, this.onSaved});

  /// Called immediately after a decision is saved (before the confirmation
  /// view is shown). Use this to trigger side-effects such as marking
  /// first-run onboarding as complete.
  final VoidCallback? onSaved;

  @override
  ConsumerState<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends ConsumerState<QuickLogSheet> {
  // ── Controllers ──────────────────────────────────────────────────────────
  final _titleCtrl = TextEditingController();
  final _outcomeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // ── Confidence slider ────────────────────────────────────────────────────
  double _confidence = 70.0;

  // ── Review date ──────────────────────────────────────────────────────────
  static const _kDefaultDays = 30;
  int _reviewDays = _kDefaultDays; // 30, 60, 90, or -1 for custom
  late DateTime _reviewDate;

  // ── Optional section ─────────────────────────────────────────────────────
  bool _showMore = false;
  String? _selectedCategoryId;
  String? _selectedStakes;

  // ── Save state ───────────────────────────────────────────────────────────
  bool _saving = false;
  bool _saved = false;
  String? _newDecisionId;

  bool get _canSave =>
      _titleCtrl.text.trim().isNotEmpty &&
      _outcomeCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _reviewDate = DateTime.now().add(const Duration(days: _kDefaultDays));
    _titleCtrl.addListener(_onTextChange);
    _outcomeCtrl.addListener(_onTextChange);
  }

  void _onTextChange() => setState(() {});

  @override
  void dispose() {
    _titleCtrl.dispose();
    _outcomeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Review date helpers ──────────────────────────────────────────────────

  void _selectReviewDays(int days) {
    setState(() {
      _reviewDays = days;
      _reviewDate = DateTime.now().add(Duration(days: days));
    });
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reviewDate.isAfter(DateTime.now())
          ? _reviewDate
          : DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _reviewDays = -1;
      _reviewDate = picked;
    });
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);

    try {
      final workspaceId = await ref.read(currentWorkspaceProvider.future);
      if (workspaceId == null) throw Exception('No workspace found');

      final repo = ref.read(decisionsRepositoryProvider);
      final confidence = (_confidence / 10).round().clamp(1, 10);

      final input = CreateDecisionInput(
        workspaceId: workspaceId,
        title: _titleCtrl.text.trim(),
        projectedOutcome: _outcomeCtrl.text.trim(),
        initialConfidence: confidence,
        state: 'Draft',
        categoryId: _selectedCategoryId,
        stakes: _selectedStakes,
        descriptionEncrypted: _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
      );

      final decisionId = await repo.createDecision(input);

      final checkpointType = switch (_reviewDays) {
        30 => '30_day',
        90 => '90_day',
        _ => 'custom',
      };

      await repo.createCheckpoint(
        decisionId: decisionId,
        checkpointType: checkpointType,
        dueAt: _reviewDate,
      );

      ref.invalidate(decisionsProvider);

      // Track in activation sequence (fire-and-forget).
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        ActivationSequenceService.trackDecisionLogged(userId).ignore();
      }

      widget.onSaved?.call();

      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
        _newDecisionId = decisionId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: AppColorScheme.destructive,
        ),
      );
    }
  }

  // ── Reset ────────────────────────────────────────────────────────────────

  void _resetAndLogAnother() {
    _titleCtrl.clear();
    _outcomeCtrl.clear();
    _notesCtrl.clear();
    setState(() {
      _confidence = 70.0;
      _reviewDays = _kDefaultDays;
      _reviewDate = DateTime.now().add(const Duration(days: _kDefaultDays));
      _showMore = false;
      _selectedCategoryId = null;
      _selectedStakes = null;
      _saving = false;
      _saved = false;
      _newDecisionId = null;
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return _saved ? _buildConfirmation(cs) : _buildForm(cs);
  }

  // ── Confirmation view ─────────────────────────────────────────────────────

  Widget _buildConfirmation(AppColorScheme cs) {
    return Container(
      color: cs.backgroundSecondary,
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF19CBD6),
            size: 56,
          ),
          const SizedBox(height: 16),
          Text(
            'Decision saved.',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'DMSans',
              color: cs.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll review this on ${_formatDate(_reviewDate)}.',
            style: TextStyle(fontSize: 14, color: cs.textTertiary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _resetAndLogAnother,
                child: const Text('Log another'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () {
                  final router = GoRouter.of(context);
                  final id = _newDecisionId!;
                  Navigator.pop(context);
                  router.push('/decisions/detail/$id');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF19CBD6),
                  foregroundColor: Colors.white,
                ),
                child: const Text('View decision'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Form view ─────────────────────────────────────────────────────────────

  Widget _buildForm(AppColorScheme cs) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Container(
      color: cs.backgroundSecondary,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header row ───────────────────────────────────────────────
            Row(
              children: [
                Text(
                  'Log a Decision',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'DMSans',
                    color: cs.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: cs.textTertiary,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Field 1: Decision title ──────────────────────────────────
            _FieldLabel('What is the decision?'),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              maxLines: 2,
              textInputAction: TextInputAction.next,
              decoration: _inputDeco(
                'e.g. Choose supplier for 500 aluminium parts',
                cs,
              ),
            ),
            const SizedBox(height: 16),

            // ── Field 2: Expected outcome ────────────────────────────────
            _FieldLabel('What outcome do you expect?'),
            const SizedBox(height: 6),
            TextField(
              controller: _outcomeCtrl,
              maxLines: 2,
              textInputAction: TextInputAction.next,
              decoration: _inputDeco(
                'e.g. Deliver on time, within budget, no rework',
                cs,
              ),
            ),
            const SizedBox(height: 16),

            // ── Field 3: Confidence slider ───────────────────────────────
            _FieldLabel(
                'How confident are you? (${_confidence.toInt()}%)'),
            const SizedBox(height: 4),
            Slider(
              min: 10,
              max: 100,
              divisions: 9,
              value: _confidence,
              activeColor: const Color(0xFF19CBD6),
              onChanged: (v) => setState(() => _confidence = v),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Text('Uncertain',
                      style:
                          TextStyle(fontSize: 11, color: cs.textTertiary)),
                  const Spacer(),
                  Text('Moderate',
                      style:
                          TextStyle(fontSize: 11, color: cs.textTertiary)),
                  const Spacer(),
                  Text('Very confident',
                      style:
                          TextStyle(fontSize: 11, color: cs.textTertiary)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Field 4: Review date chips ───────────────────────────────
            _FieldLabel('When should this be reviewed?'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in [
                  (30, '30 days'),
                  (60, '60 days'),
                  (90, '90 days'),
                ])
                  _ReviewChip(
                    label: entry.$2,
                    selected: _reviewDays == entry.$1,
                    onTap: () => _selectReviewDays(entry.$1),
                    cs: cs,
                  ),
                _ReviewChip(
                  label: _reviewDays == -1
                      ? _formatDate(_reviewDate)
                      : 'Custom',
                  selected: _reviewDays == -1,
                  onTap: _pickCustomDate,
                  cs: cs,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Optional section toggle ──────────────────────────────────
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showMore = !_showMore),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showMore
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: const Color(0xFF19CBD6),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Add more detail',
                    style: TextStyle(
                      color: Color(0xFF19CBD6),
                      fontSize: 13,
                      fontFamily: 'DMSans',
                    ),
                  ),
                ],
              ),
            ),

            // ── Optional section body ────────────────────────────────────
            if (_showMore) ...[
              const SizedBox(height: 16),

              // Category
              _FieldLabel('Category'),
              const SizedBox(height: 8),
              categoriesAsync.when(
                loading: () => const LinearProgressIndicator(
                  color: Color(0xFF19CBD6),
                  minHeight: 2,
                ),
                error: (_, _) => const SizedBox.shrink(),
                data: (cats) => cats.isEmpty
                    ? Text('No categories set up.',
                        style: TextStyle(
                            fontSize: 12, color: cs.textTertiary))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final cat in cats)
                            _ReviewChip(
                              label: cat.name,
                              selected: _selectedCategoryId == cat.id,
                              onTap: () => setState(() {
                                _selectedCategoryId =
                                    _selectedCategoryId == cat.id
                                        ? null
                                        : cat.id;
                              }),
                              cs: cs,
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),

              // Stakes
              _FieldLabel('Stakes'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in ['Low', 'Medium', 'High', 'Critical'])
                    _ReviewChip(
                      label: s,
                      selected: _selectedStakes == s,
                      onTap: () => setState(() {
                        _selectedStakes =
                            _selectedStakes == s ? null : s;
                      }),
                      cs: cs,
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Notes
              _FieldLabel('Notes'),
              const SizedBox(height: 6),
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: _inputDeco('Optional notes...', cs),
              ),
            ],

            const SizedBox(height: 24),

            // ── Save button ──────────────────────────────────────────────
            FilledButton(
              onPressed: _canSave && !_saving ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF19CBD6),
                disabledBackgroundColor:
                    const Color(0xFF19CBD6).withValues(alpha: 0.35),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdBR),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Save Decision',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'DMSans',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, AppColorScheme cs) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: cs.textTertiary, fontSize: 14),
        filled: true,
        fillColor: cs.backgroundElevated,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdBR,
          borderSide: BorderSide(color: cs.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBR,
          borderSide: BorderSide(color: cs.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBR,
          borderSide:
              const BorderSide(color: Color(0xFF19CBD6), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
}

// ── Shared chip widget ────────────────────────────────────────────────────────

class _ReviewChip extends StatelessWidget {
  const _ReviewChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFF19CBD6),
      backgroundColor: cs.backgroundElevated,
      labelStyle: TextStyle(
        color: selected ? Colors.white : cs.textSecondary,
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
      side: BorderSide(
        color:
            selected ? const Color(0xFF19CBD6) : cs.borderDefault,
      ),
      showCheckmark: false,
    );
  }
}

// ── Field label ───────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.cs.textSecondary,
        fontFamily: 'DMSans',
      ),
    );
  }
}
