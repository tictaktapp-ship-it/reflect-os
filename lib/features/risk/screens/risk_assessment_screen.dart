import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/workspace_ai_provider.dart';
import 'package:reflect_os/features/risk/data/models/risk_assessment.dart';
import 'package:reflect_os/features/risk/providers/risk_provider.dart';
import 'package:reflect_os/widgets/app_header.dart';
import 'package:reflect_os/widgets/dialog_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reflect_os/core/theme/app_radius.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _riskColors = {
  'low': Color(0xFF2EA073),
  'medium': Color(0xFFD97D24),
  'high': Color(0xFFDC4444),
  'critical': Color(0xFF7C3AED),
};

const _likelihoodLabels = ['', 'Rare', 'Unlikely', 'Possible', 'Likely', 'Almost Certain'];
const _impactLabels = ['', 'Negligible', 'Minor', 'Moderate', 'Major', 'Catastrophic'];

Color riskColor(String? level) =>
    _riskColors[level?.toLowerCase()] ?? AppColors.textSecondary;

String _severityFor(int likelihood, int impact) {
  final score = likelihood * impact;
  if (score <= 4) return 'low';
  if (score <= 9) return 'medium';
  if (score <= 16) return 'high';
  return 'critical';
}

int _confidenceImpactFor(String level) => switch (level) {
      'low' => 0,
      'medium' => -1,
      'high' => -2,
      'critical' => -3,
      _ => 0,
    };

String _overallLevelFor(List<Map<String, dynamic>> risks) {
  const order = ['low', 'medium', 'high', 'critical'];
  var max = 0;
  for (final r in risks) {
    final idx = order.indexOf((r['severity'] as String?) ?? 'low');
    if (idx > max) max = idx;
  }
  return order[max];
}

// ── Screen ────────────────────────────────────────────────────────────────────

enum _Step { chooseMethod, build, review, approve }

class RiskAssessmentScreen extends ConsumerStatefulWidget {
  const RiskAssessmentScreen({
    required this.decisionId,
    this.existingAssessment,
    super.key,
  });

  final String decisionId;

  /// When set, open in read-only review mode (skips steps A and B).
  final RiskAssessment? existingAssessment;

  @override
  ConsumerState<RiskAssessmentScreen> createState() =>
      _RiskAssessmentScreenState();
}

class _RiskAssessmentScreenState
    extends ConsumerState<RiskAssessmentScreen> {
  _Step _step = _Step.chooseMethod;
  bool _isAI = true;
  bool _isLoading = false;
  RiskAssessment? _pendingAssessment;

  // Manual risks being built
  final List<Map<String, dynamic>> _manualRisks = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingAssessment != null) {
      _pendingAssessment = widget.existingAssessment;
      _step = _Step.review;
    }
  }

  // ── Step B: AI consent + generate ────────────────────────────────────────

  Future<void> _showAIConsentAndGenerate() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogShell(
        title: 'AI data notice',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _riskConsentBullet(
                'Your decision details will be sent to an AI service'),
            _riskConsentBullet(
                'Do not include highly confidential or legally sensitive data'),
            _riskConsentBullet(
                'By continuing you confirm you are authorised to share this '
                'content with an external AI service'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF19CBD6)),
            child: const Text('I understand, continue'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      _runAIGeneration();
    }
  }

  Widget _riskConsentBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(
                  color: Color(0xFF19CBD6), fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF475569))),
          ),
        ],
      ),
    );
  }

  // ── Step B: AI generate ───────────────────────────────────────────────────

  Future<void> _runAIGeneration() async {
    setState(() => _isLoading = true);
    try {
      final assessment = await ref
          .read(riskRepositoryProvider)
          .generateRiskAssessment(widget.decisionId);
      if (!mounted) return;
      setState(() {
        _pendingAssessment = assessment;
        _step = _Step.review;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generation failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Step B: Manual proceed to review ────────────────────────────────────

  Future<void> _saveManualAndReview() async {
    if (_manualRisks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one risk before reviewing.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final overallLevel = _overallLevelFor(_manualRisks);
      final assessment = await ref
          .read(riskRepositoryProvider)
          .saveManualRiskAssessment(
            decisionId: widget.decisionId,
            risks: _manualRisks,
            overallRiskLevel: overallLevel,
          );
      if (!mounted) return;
      setState(() {
        _pendingAssessment = assessment;
        _step = _Step.review;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Step D: Approve ───────────────────────────────────────────────────────

  Future<void> _approve() async {
    final assessment = _pendingAssessment;
    if (assessment == null) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      final level = assessment.overallRiskLevel ?? 'medium';
      await ref.read(riskRepositoryProvider).approveRiskAssessment(
            assessmentId: assessment.id,
            userId: userId,
            confidenceImpact: _confidenceImpactFor(level),
            overallRiskLevel: level,
          );
      ref.invalidate(riskAssessmentProvider(widget.decisionId));
      ref.invalidate(approvedRiskAssessmentProvider(widget.decisionId));
      ref.invalidate(riskConfidenceAdjustmentProvider(widget.decisionId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Risk assessment approved')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approval failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final readOnly =
        widget.existingAssessment?.isApproved == true;

    final aiEnabled =
        ref.watch(workspaceAiEnabledProvider).valueOrNull ?? true;

    return Scaffold(
      appBar: AppHeader(
        automaticallyImplyLeading: true,
        title: 'Risk Assessment',
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: switch (_step) {
            _Step.chooseMethod => _ChooseMethodStep(
                aiEnabled: aiEnabled,
                onChoose: (isAI) => setState(() {
                  _isAI = isAI;
                  _step = _Step.build;
                }),
              ),
            _Step.build => _isAI
                ? _AIBuildStep(
                    decisionId: widget.decisionId,
                    isLoading: _isLoading,
                    onGenerate: _showAIConsentAndGenerate,
                  )
                : _ManualBuildStep(
                    risks: _manualRisks,
                    isLoading: _isLoading,
                    onRisksChanged: (r) => setState(() {
                      _manualRisks
                        ..clear()
                        ..addAll(r);
                    }),
                    onReview: _saveManualAndReview,
                    onBack: () => setState(() => _step = _Step.chooseMethod),
                  ),
            _Step.review => _ReviewStep(
                assessment: _pendingAssessment,
                readOnly: readOnly,
                onBack: readOnly
                    ? null
                    : () => setState(() => _step = _Step.build),
                onApprove: readOnly
                    ? null
                    : () => setState(() => _step = _Step.approve),
              ),
            _Step.approve => _ApproveStep(
                assessment: _pendingAssessment,
                isLoading: _isLoading,
                onApprove: _approve,
                onBack: () => setState(() => _step = _Step.review),
              ),
          },
        ),
      ),
    );
  }
}

// ── Step A: Choose method ─────────────────────────────────────────────────────

class _ChooseMethodStep extends StatelessWidget {
  const _ChooseMethodStep({
    required this.onChoose,
    required this.aiEnabled,
  });
  final void Function(bool isAI) onChoose;
  final bool aiEnabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How would you like to create this risk assessment?',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: aiEnabled
                    ? _MethodCard(
                        icon: Icons.auto_awesome,
                        iconColor: AppColors.accentPrimary,
                        title: 'Generate with AI',
                        description:
                            'AI analyses your decision and identifies key risks automatically.',
                        onTap: () => onChoose(true),
                      )
                    : _DisabledAICard(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MethodCard(
                  icon: Icons.edit_note,
                  iconColor: const Color(0xFF334155),
                  title: 'Create manually',
                  description:
                      'Enter risks yourself using the ISO 31000 framework (likelihood × impact).',
                  onTap: () => onChoose(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DisabledAICard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: AppRadius.mdBR,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_outlined,
                color: Color(0xFFCBD5E1), size: 24),
          ),
          const SizedBox(height: 14),
          const Text('Generate with AI',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8))),
          const SizedBox(height: 6),
          const Text('AI disabled for this workspace',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdBR,
        side: BorderSide(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 14),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step B (AI path) ──────────────────────────────────────────────────────────

class _AIBuildStep extends ConsumerWidget {
  const _AIBuildStep({
    required this.decisionId,
    required this.isLoading,
    required this.onGenerate,
  });

  final String decisionId;
  final bool isLoading;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI Risk Assessment',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'AI will analyse your decision title, stakes, and description '
            'to identify key risks using the ISO 31000 framework.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 32),
          if (isLoading)
            const Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Analysing decision with AI…'),
              ],
            )
          else
            FilledButton.icon(
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Generate risk assessment'),
              onPressed: onGenerate,
            ),
          const SizedBox(height: 16),
          Text(
            'AI-generated · Always review independently',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
          ),
        ],
      ),
    );
  }
}

// ── Step B (Manual path) ──────────────────────────────────────────────────────

class _ManualBuildStep extends StatefulWidget {
  const _ManualBuildStep({
    required this.risks,
    required this.isLoading,
    required this.onRisksChanged,
    required this.onReview,
    required this.onBack,
  });

  final List<Map<String, dynamic>> risks;
  final bool isLoading;
  final ValueChanged<List<Map<String, dynamic>>> onRisksChanged;
  final VoidCallback onReview;
  final VoidCallback onBack;

  @override
  State<_ManualBuildStep> createState() => _ManualBuildStepState();
}

class _ManualBuildStepState extends State<_ManualBuildStep> {
  late final List<Map<String, dynamic>> _risks =
      List<Map<String, dynamic>>.from(widget.risks);

  void _addRisk() {
    setState(() {
      _risks.add({
        'title': '',
        'description': '',
        'likelihood': 3,
        'impact': 3,
        'severity': _severityFor(3, 3),
        'mitigation': '',
      });
    });
    widget.onRisksChanged(_risks);
  }

  void _removeRisk(int index) {
    setState(() => _risks.removeAt(index));
    widget.onRisksChanged(_risks);
  }

  void _updateRisk(int index, Map<String, dynamic> updated) {
    setState(() => _risks[index] = updated);
    widget.onRisksChanged(_risks);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Text('Manual Risk Entry',
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back'),
              onPressed: widget.onBack,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'ISO 31000 framework · Severity = likelihood × impact',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
        ),
        const SizedBox(height: 16),
        ...List.generate(_risks.length, (i) => _RiskEntryCard(
              index: i,
              risk: _risks[i],
              onChanged: (updated) => _updateRisk(i, updated),
              onRemove: () => _removeRisk(i),
            )),
        const SizedBox(height: 8),
        TextButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add another risk'),
          onPressed: _addRisk,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: widget.isLoading ? null : widget.onReview,
          child: widget.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Review assessment'),
        ),
      ],
    );
  }
}

class _RiskEntryCard extends StatefulWidget {
  const _RiskEntryCard({
    required this.index,
    required this.risk,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final Map<String, dynamic> risk;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onRemove;

  @override
  State<_RiskEntryCard> createState() => _RiskEntryCardState();
}

class _RiskEntryCardState extends State<_RiskEntryCard> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _mitigCtrl;
  late int _likelihood;
  late int _impact;

  @override
  void initState() {
    super.initState();
    _titleCtrl =
        TextEditingController(text: widget.risk['title'] as String? ?? '');
    _descCtrl = TextEditingController(
        text: widget.risk['description'] as String? ?? '');
    _mitigCtrl = TextEditingController(
        text: widget.risk['mitigation'] as String? ?? '');
    _likelihood = (widget.risk['likelihood'] as num?)?.toInt() ?? 3;
    _impact = (widget.risk['impact'] as num?)?.toInt() ?? 3;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _mitigCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final severity = _severityFor(_likelihood, _impact);
    widget.onChanged({
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'likelihood': _likelihood,
      'impact': _impact,
      'severity': severity,
      'mitigation': _mitigCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final severity = _severityFor(_likelihood, _impact);
    final sevColor = riskColor(severity);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Risk ${widget.index + 1}',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                _SeverityChip(severity: severity),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: AppColors.destructive),
                  tooltip: 'Remove',
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Risk title *'),
              onChanged: (_) => _emit(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
              onChanged: (_) => _emit(),
            ),
            const SizedBox(height: 14),
            // Likelihood slider
            _SliderRow(
              label: 'Likelihood',
              value: _likelihood,
              sublabel: _likelihoodLabels[_likelihood],
              color: sevColor,
              onChanged: (v) {
                setState(() => _likelihood = v);
                _emit();
              },
            ),
            const SizedBox(height: 8),
            // Impact slider
            _SliderRow(
              label: 'Impact',
              value: _impact,
              sublabel: _impactLabels[_impact],
              color: sevColor,
              onChanged: (v) {
                setState(() => _impact = v);
                _emit();
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _mitigCtrl,
              decoration: const InputDecoration(labelText: 'Mitigation'),
              maxLines: 2,
              onChanged: (_) => _emit(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.sublabel,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final int value;
  final String sublabel;
  final Color color;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(width: 8),
            Text(
              '$value – $sublabel',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: color),
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: color,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}

// ── Step C: Review ────────────────────────────────────────────────────────────

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.assessment,
    required this.readOnly,
    required this.onBack,
    required this.onApprove,
  });

  final RiskAssessment? assessment;
  final bool readOnly;
  final VoidCallback? onBack;
  final VoidCallback? onApprove;

  @override
  Widget build(BuildContext context) {
    if (assessment == null) {
      return const Center(child: Text('No assessment data.'));
    }

    final level = assessment!.overallRiskLevel ?? 'medium';
    final color = riskColor(level);
    final risks = assessment!.risks;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Text('Review Assessment',
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            if (onBack != null)
              TextButton.icon(
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back'),
                onPressed: onBack,
              ),
          ],
        ),
        const SizedBox(height: 16),
        // Overall risk badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: AppRadius.mdBR,
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                'Overall risk: ${level.toUpperCase()}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${_confidenceImpactFor(level) == 0 ? 'no' : _confidenceImpactFor(level).toString()} confidence impact)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color.withValues(alpha: 0.8),
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...risks.map((r) => _ReviewRiskCard(risk: r)),
        const SizedBox(height: 24),
        if (readOnly)
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          )
        else
          FilledButton(
            onPressed: onApprove,
            child: const Text('Approve assessment'),
          ),
      ],
    );
  }
}

class _ReviewRiskCard extends StatelessWidget {
  const _ReviewRiskCard({required this.risk});
  final Map<String, dynamic> risk;

  @override
  Widget build(BuildContext context) {
    final title = risk['title'] as String? ?? 'Untitled';
    final description = risk['description'] as String? ?? '';
    final severity = risk['severity'] as String? ?? 'medium';
    final likelihood = (risk['likelihood'] as num?)?.toInt() ?? 0;
    final impact = (risk['impact'] as num?)?.toInt() ?? 0;
    final mitigation = risk['mitigation'] as String? ?? '';
    final color = riskColor(severity);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                _SeverityChip(severity: severity),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(description,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (likelihood > 0)
                  _MetaPill(
                    label: 'L: $likelihood ${_likelihoodLabels[likelihood]}',
                    color: color,
                  ),
                if (impact > 0)
                  _MetaPill(
                    label: 'I: $impact ${_impactLabels[impact]}',
                    color: color,
                  ),
              ],
            ),
            if (mitigation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined,
                      size: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      mitigation,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.65),
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Step D: Approve ───────────────────────────────────────────────────────────

class _ApproveStep extends StatelessWidget {
  const _ApproveStep({
    required this.assessment,
    required this.isLoading,
    required this.onApprove,
    required this.onBack,
  });

  final RiskAssessment? assessment;
  final bool isLoading;
  final VoidCallback onApprove;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    if (assessment == null) return const SizedBox.shrink();

    final level = assessment!.overallRiskLevel ?? 'medium';
    final color = riskColor(level);
    final impact = _confidenceImpactFor(level);
    final impactStr = impact == 0 ? 'None' : '$impact';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Approve Assessment',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          Card(
            color: color.withValues(alpha: 0.06),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.mdBR,
              side: BorderSide(color: color.withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ApproveRow(
                    icon: Icons.shield_outlined,
                    label: 'Overall risk level',
                    value: level.toUpperCase(),
                    valueColor: color,
                  ),
                  const SizedBox(height: 10),
                  _ApproveRow(
                    icon: Icons.signal_cellular_alt_outlined,
                    label: 'Confidence impact',
                    value: impactStr,
                    valueColor: impact < 0 ? AppColors.destructive : AppColors.success,
                  ),
                  const SizedBox(height: 10),
                  _ApproveRow(
                    icon: Icons.format_list_numbered,
                    label: 'Risks identified',
                    value: '${assessment!.risks.length}',
                    valueColor: Theme.of(context).colorScheme.onSurface,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Approving will record this assessment, adjust effective confidence, '
            'and update the health status for this decision.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55),
                ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              TextButton(
                onPressed: isLoading ? null : onBack,
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: isLoading ? null : onApprove,
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Approve risk assessment'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApproveRow extends StatelessWidget {
  const _ApproveRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon,
            size: 16,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.65),
                  )),
        ),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: valueColor, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.severity});
  final String severity;

  @override
  Widget build(BuildContext context) {
    final color = riskColor(severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.smBR,
      ),
      child: Text(
        severity.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.smBR,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: 10,
            ),
      ),
    );
  }
}
