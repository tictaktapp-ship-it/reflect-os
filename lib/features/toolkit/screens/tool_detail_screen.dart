import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/routing/routes.dart';
import '../data/models/tool_definition.dart';
import '../data/models/tool_preset.dart';
import '../data/toolkit_repository.dart';
import '../engine/calculator_engine.dart';

/// Tool input form — V2. Dynamically renders sections from input_schema_jsonb,
/// runs the calculator engine locally, then persists via the two-call RPC flow.
class ToolDetailScreen extends ConsumerStatefulWidget {
  const ToolDetailScreen({
    super.key,
    required this.toolId,
    this.decisionId,
    this.tool,
  });

  final String toolId;
  final String? decisionId;
  final ToolDefinition? tool;

  @override
  ConsumerState<ToolDetailScreen> createState() => _ToolDetailScreenState();
}

class _ToolDetailScreenState extends ConsumerState<ToolDetailScreen> {
  final _formKey = GlobalKey<FormState>();

  /// Flat map of field_id → raw String value (for text/number/select).
  final Map<String, dynamic> _inputs = {};

  /// For array fields: list of per-row maps of sub-field-id → TextEditingController.
  final Map<String, List<Map<String, TextEditingController>>>
      _objectRowControllers = {};

  int    _projectionYears     = 3;
  String _confidenceScenario  = 'base';
  final  String _currencyCode = 'GBP';
  bool   _isRunning           = false;
  String? _validationError;
  List<ToolPreset> _presets   = [];
  ToolPreset? _defaultPreset;

  ToolDefinition? get _tool => widget.tool;

  @override
  void initState() {
    super.initState();
    final tool = _tool;
    if (tool != null) {
      _projectionYears = tool.defaultProjectionYears;
      _initDefaults(tool);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPresets());
  }

  void _initDefaults(ToolDefinition tool) {
    for (final section in tool.sections) {
      final fields =
          (section as Map<String, dynamic>)['fields'] as List<dynamic>? ?? [];
      for (final f in fields) {
        final field = f as Map<String, dynamic>;
        final id    = field['id'] as String;
        final def   = field['default'];
        if (def != null) _inputs[id] = def.toString();
        if ((field['type'] as String?) == 'array') {
          _objectRowControllers[id] = [];
          _addObjectRow(id, field['item_schema'] as Map<String, dynamic>? ?? {});
        }
      }
    }
  }

  Future<void> _loadPresets() async {
    final tool        = _tool;
    final workspaceId = ref.read(currentWorkspaceProvider).valueOrNull;
    if (tool == null || workspaceId == null) return;
    try {
      final presets = await const ToolkitRepository().getPresetsForTool(
        workspaceId: workspaceId,
        toolDefinitionId: tool.id,
      );
      if (mounted) {
        setState(() {
          _presets = presets;
          _defaultPreset = presets.where((p) => p.isWorkspaceDefault).firstOrNull;
        });
      }
    } catch (_) {}
  }

  void _prefillForm(Map<String, dynamic> inputs) {
    setState(() {
      inputs.forEach((k, v) {
        _inputs[k] = v.toString();
      });
    });
  }

  void _addObjectRow(String fieldId, Map<String, dynamic> schema) {
    final row = <String, TextEditingController>{};
    for (final key in schema.keys) {
      row[key] = TextEditingController();
    }
    setState(() => _objectRowControllers[fieldId]!.add(row));
  }

  void _removeObjectRow(String fieldId, int index) {
    final row = _objectRowControllers[fieldId]!.removeAt(index);
    for (final c in row.values) {
      c.dispose();
    }
    setState(() {});
  }

  void _applyPreset(ToolPreset preset) {
    setState(() {
      preset.inputsJsonb.forEach((k, v) {
        _inputs[k] = v.toString();
      });
    });
  }

  @override
  void dispose() {
    for (final rows in _objectRowControllers.values) {
      for (final row in rows) {
        for (final c in row.values) {
          c.dispose();
        }
      }
    }
    super.dispose();
  }

  // ── Run flow ─────────────────────────────────────────────────────────────

  Future<void> _run() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final tool = _tool;
    if (tool == null) return;

    final workspaceId = ref.read(currentWorkspaceProvider).valueOrNull;
    if (workspaceId == null) {
      _showError('No active workspace found.');
      return;
    }

    setState(() {
      _isRunning       = true;
      _validationError = null;
    });

    try {
      final inputs = _collectInputs(tool);

      // Step 1: Compute locally (synchronous, no network)
      final result = const CalculatorEngine().compute(
        toolKey:             tool.key,
        inputs:              inputs,
        projectionYears:     _projectionYears,
        confidenceScenario:  _confidenceScenario,
        currencyCode:        _currencyCode,
      );

      if (!result.isValid) {
        setState(() => _validationError = result.validationError);
        return;
      }

      // Step 2: Persist shell run row
      final repo    = const ToolkitRepository();
      final toolRun = await repo.runTool(
        toolDefinitionId:  tool.id,
        workspaceId:       workspaceId,
        inputsJsonb:       inputs,
        decisionId:        widget.decisionId,
        projectionYears:   _projectionYears,
        currencyCode:      _currencyCode,
        confidenceScenario: _confidenceScenario,
      );

      if (!mounted) return;

      // Step 3: Navigate to results, forwarding pickerMode if present.
      final pickerMode =
          GoRouterState.of(context).uri.queryParameters['pickerMode'] == 'true';
      var resultsPath = Routes.toolResults.replaceFirst(':toolId', tool.id);
      if (pickerMode) resultsPath = '$resultsPath?pickerMode=true';

      if (pickerMode) {
        // Await the results screen so we can propagate the user's selection
        // back through the toolkit picker chain to the decision form.
        final pickerResult = await context.push<String?>(
          resultsPath,
          extra: (
            result:     result,
            run:        toolRun,
            tool:       tool,
            decisionId: widget.decisionId,
          ),
        );
        if (pickerResult != null && pickerResult.isNotEmpty && mounted) {
          context.pop(pickerResult);
        }
      } else {
        context.push(
          resultsPath,
          extra: (
            result:     result,
            run:        toolRun,
            tool:       tool,
            decisionId: widget.decisionId,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to run tool: $e');
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  Map<String, dynamic> _collectInputs(ToolDefinition tool) {
    final inputs = <String, dynamic>{};
    for (final section in tool.sections) {
      final fields = (section as Map<String, dynamic>)['fields'] as List<dynamic>? ?? [];
      for (final f in fields) {
        final field   = f as Map<String, dynamic>;
        final id      = field['id'] as String;
        final type    = field['type'] as String? ?? 'text';

        if (type == 'number') {
          final raw = (_inputs[id] as String? ?? '').trim();
          inputs[id] = double.tryParse(raw) ?? 0.0;
        } else if (type == 'select') {
          inputs[id] = _inputs[id] as String? ?? '';
        } else if (type == 'text') {
          inputs[id] = (_inputs[id] as String? ?? '').trim();
        } else if (type == 'array') {
          final rows = _objectRowControllers[id] ?? [];
          inputs[id] = rows.map((row) {
            return row.map(
              (key, ctrl) =>
                  MapEntry(key, double.tryParse(ctrl.text.trim()) ?? 0.0),
            );
          }).toList();
        }
      }
    }
    return inputs;
  }

  // ── Example preset ───────────────────────────────────────────────────────

  void _showExample(ToolPreset preset) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: context.cs.backgroundSecondary,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(
                color: const Color(0xFF19CBD6).withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.cs.borderDefault,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97D24).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFFD97D24)
                                .withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_outlined,
                              size: 13, color: Color(0xFFD97D24)),
                          SizedBox(width: 5),
                          Text(
                            'EXAMPLE ONLY — Read only',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFD97D24),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.cs.textPrimary,
                      ),
                    ),
                    if (preset.description != null)
                      Text(
                        preset.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.cs.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(),
              // Read-only form
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: _buildReadOnlyForm(preset.inputsJsonb),
                ),
              ),
              // Use as starting point
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Use as starting point'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF19CBD6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _prefillForm(preset.inputsJsonb);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyForm(Map<String, dynamic> inputs) {
    final tool = _tool;
    if (tool == null) return const SizedBox.shrink();

    // Build a lookup map: field_id → field schema
    final fieldInfo = <String, Map<String, dynamic>>{};
    for (final section in tool.sections) {
      final fields =
          (section as Map<String, dynamic>)['fields'] as List<dynamic>? ?? [];
      for (final f in fields) {
        final field = f as Map<String, dynamic>;
        final id = field['id'] as String;
        fieldInfo[id] = field;
      }
    }

    final cs = context.cs;
    final entries = inputs.entries
        .where((e) => !e.key.startsWith('__'))
        .toList();

    return Column(
      children: entries.map((e) {
        final info = fieldInfo[e.key];
        final label = info?['label'] as String? ?? e.key;
        final unit = info?['unit'] as String?;
        final type = info?['type'] as String? ?? 'text';
        final displayLabel = unit != null ? '$label ($unit)' : label;

        String displayValue;
        if (e.value is List) {
          displayValue = (e.value as List)
              .map((row) => row is Map
                  ? (row as Map<String, dynamic>)
                      .entries
                      .map((kv) => '${kv.key}: ${kv.value}')
                      .join(', ')
                  : row.toString())
              .join('\n');
        } else if (type == 'number' && e.value != null) {
          final n = num.tryParse(e.value.toString());
          displayValue = n != null ? n.toStringAsFixed(2) : e.value.toString();
        } else {
          displayValue = e.value?.toString() ?? '—';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  displayLabel,
                  style: TextStyle(fontSize: 13, color: cs.textSecondary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.textPrimary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Save preset ──────────────────────────────────────────────────────────

  Future<void> _showSavePresetSheet() async {
    final tool        = _tool;
    final workspaceId = ref.read(currentWorkspaceProvider).valueOrNull;
    if (tool == null || workspaceId == null) return;

    String presetName = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 24,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Save preset',
                style: Theme.of(ctx).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Preset name',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => presetName = v,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (presetName.trim().isEmpty) return;
                  try {
                    await const ToolkitRepository().savePreset(
                      workspaceId:      workspaceId,
                      toolDefinitionId: tool.id,
                      name:             presetName.trim(),
                      inputsJsonb:      _collectInputs(tool),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Preset saved')),
                      );
                      _loadPresets();
                    }
                  } catch (e) {
                    if (mounted) _showError('Failed to save preset: $e');
                  }
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tool = _tool;
    if (tool == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tool')),
        body: const Center(child: Text('Tool not found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tool.name),
        actions: [
          if (_defaultPreset != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.visibility_outlined, size: 15),
                label: const Text('See example'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF19CBD6),
                  side: const BorderSide(
                      color: Color(0xFF19CBD6), width: 0.4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                onPressed: () => _showExample(_defaultPreset!),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: 'Save preset',
            onPressed: _showSavePresetSheet,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Description
            if (tool.description.isNotEmpty) ...[
              Text(
                tool.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 16),
            ],

            // Preset bar
            if (_presets.isNotEmpty) ...[
              _PresetBar(presets: _presets, onSelect: _applyPreset),
              const SizedBox(height: 16),
            ],

            // Projection years slider
            if (tool.hasProjectionYearsField) ...[
              _ProjectionYearsSlider(
                value: _projectionYears,
                min: tool.minProjectionYears,
                max: tool.maxProjectionYears,
                onChanged: (v) => setState(() => _projectionYears = v),
              ),
              const SizedBox(height: 16),
            ],

            // Confidence scenario selector
            if (tool.confidenceMode == 'per_field') ...[
              _ConfidenceSelector(
                value: _confidenceScenario,
                onChanged: (v) => setState(() => _confidenceScenario = v),
              ),
              const SizedBox(height: 16),
            ],

            // Dynamic sections
            ...tool.sections.map((s) {
              final section = s as Map<String, dynamic>;
              return _SectionWidget(
                section: section,
                inputs: _inputs,
                objectRowControllers: _objectRowControllers,
                confidenceScenario: _confidenceScenario,
                onInputChanged: (id, val) =>
                    setState(() => _inputs[id] = val),
                onAddRow: _addObjectRow,
                onRemoveRow: _removeObjectRow,
              );
            }),

            // Validation error
            if (_validationError != null) ...[
              const SizedBox(height: 8),
              Text(
                _validationError!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.destructive),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isRunning ? null : _run,
                child: _isRunning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Calculate'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Preset bar ────────────────────────────────────────────────────────────────

class _PresetBar extends StatelessWidget {
  const _PresetBar({required this.presets, required this.onSelect});

  final List<ToolPreset> presets;
  final void Function(ToolPreset) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Presets',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: presets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ActionChip(
              label: Text(presets[i].name),
              onPressed: () => onSelect(presets[i]),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Projection years slider ───────────────────────────────────────────────────

class _ProjectionYearsSlider extends StatelessWidget {
  const _ProjectionYearsSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Years to project:',
            style: Theme.of(context).textTheme.labelMedium),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (v) => onChanged(v.toInt()),
          ),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ── Confidence scenario selector ──────────────────────────────────────────────

class _ConfidenceSelector extends StatelessWidget {
  const _ConfidenceSelector({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Scenario:', style: theme.textTheme.labelMedium),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'pessimistic', label: Text('Pessimistic ↓')),
            ButtonSegment(value: 'base',        label: Text('Base')),
            ButtonSegment(value: 'optimistic',  label: Text('Optimistic ↑')),
          ],
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ],
    );
  }
}

// ── Section widget ────────────────────────────────────────────────────────────

class _SectionWidget extends StatelessWidget {
  const _SectionWidget({
    required this.section,
    required this.inputs,
    required this.objectRowControllers,
    required this.confidenceScenario,
    required this.onInputChanged,
    required this.onAddRow,
    required this.onRemoveRow,
  });

  final Map<String, dynamic> section;
  final Map<String, dynamic> inputs;
  final Map<String, List<Map<String, TextEditingController>>>
      objectRowControllers;
  final String confidenceScenario;
  final void Function(String id, String val) onInputChanged;
  final void Function(String fieldId, Map<String, dynamic> schema) onAddRow;
  final void Function(String fieldId, int index) onRemoveRow;

  @override
  Widget build(BuildContext context) {
    final title       = section['title'] as String? ?? '';
    final description = section['description'] as String?;
    final fields      = (section['fields'] as List<dynamic>?) ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            if (description != null && description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 8),
                child: Text(description,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary)),
              )
            else
              const SizedBox(height: 8),
          ],
          ...fields.map((f) {
            final field = f as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildFieldWidget(context, field),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFieldWidget(BuildContext context, Map<String, dynamic> field) {
    final id      = field['id'] as String;
    final type    = field['type'] as String? ?? 'text';
    final label   = field['label'] as String? ?? id;
    final unit    = field['unit'] as String?;
    final hint    = field['hint'] as String?;
    final tooltip = field['tooltip'] as String?;
    final typicalRange = field['typical_range'] as String?;
    final required = field['required'] as bool? ?? false;
    final min      = (field['min'] as num?)?.toDouble();
    final max      = (field['max'] as num?)?.toDouble();
    final options  = (field['options'] as List<dynamic>?)
        ?.map((o) => o.toString())
        .toList();
    final confidenceEnabled = field['confidence_enabled'] as bool? ?? false;

    // Build label with optional ⓘ icon that shows a help dialog
    Widget labelWidget = Text(
      unit != null ? '$label ($unit)' : label,
      style: Theme.of(context).textTheme.labelMedium,
    );
    if (tooltip != null || hint != null || typicalRange != null) {
      labelWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          labelWidget,
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _showFieldHelpDialog(
                context, label, tooltip, hint, typicalRange),
            child: Icon(
              Icons.info_outline,
              size: 15,
              color: const Color(0xFF19CBD6).withValues(alpha: 0.7),
            ),
          ),
        ],
      );
    }

    // Determine border colour for confidence-enabled fields
    final confidenceBorderColor = confidenceEnabled
        ? switch (confidenceScenario) {
            'optimistic'  => AppColors.success,
            'pessimistic' => AppColors.destructive,
            _             => null,
          }
        : null;

    final border = confidenceBorderColor != null
        ? OutlineInputBorder(
            borderSide: BorderSide(color: confidenceBorderColor, width: 1.5),
          )
        : const OutlineInputBorder();

    if (type == 'number') {
      return TextFormField(
        initialValue: inputs[id] as String?,
        keyboardType: const TextInputType.numberWithOptions(
            decimal: true, signed: true),
        decoration: InputDecoration(
          label: labelWidget,
          hintText: hint,
          border: const OutlineInputBorder(),
          enabledBorder: border,
        ),
        validator: (v) {
          if (required && (v == null || v.trim().isEmpty)) {
            return '$label is required';
          }
          if (v != null && v.trim().isNotEmpty) {
            final parsed = double.tryParse(v.trim());
            if (parsed == null) return 'Enter a number';
            if (min != null && parsed < min) return 'Minimum is $min';
            if (max != null && parsed > max) return 'Maximum is $max';
          }
          return null;
        },
        onChanged: (v) => onInputChanged(id, v),
      );
    }

    if (type == 'select' && options != null) {
      return DropdownButtonFormField<String>(
        initialValue: inputs[id] as String?,
        decoration: InputDecoration(
          label: labelWidget,
          border: const OutlineInputBorder(),
        ),
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        validator: required
            ? (v) => (v == null || v.isEmpty) ? '$label is required' : null
            : null,
        onChanged: (v) {
          if (v != null) onInputChanged(id, v);
        },
      );
    }

    if (type == 'text') {
      return TextFormField(
        initialValue: inputs[id] as String?,
        decoration: InputDecoration(
          label: labelWidget,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? '$label is required' : null
            : null,
        onChanged: (v) => onInputChanged(id, v),
      );
    }

    if (type == 'array') {
      final itemSchema =
          field['item_schema'] as Map<String, dynamic>? ?? {};
      final rows   = objectRowControllers[id] ?? [];
      final maxItems = (field['max_items'] as num?)?.toInt();
      return _ArrayField(
        label: label,
        rows: rows,
        schema: itemSchema,
        canAdd: maxItems == null || rows.length < maxItems,
        onAdd: () => onAddRow(id, itemSchema),
        onRemove: (i) => onRemoveRow(id, i),
      );
    }

    return const SizedBox.shrink();
  }
}

// ── Array field widget ────────────────────────────────────────────────────────

class _ArrayField extends StatelessWidget {
  const _ArrayField({
    required this.label,
    required this.rows,
    required this.schema,
    required this.canAdd,
    required this.onAdd,
    required this.onRemove,
  });

  final String label;
  final List<Map<String, TextEditingController>> rows;
  final Map<String, dynamic> schema;
  final bool canAdd;
  final VoidCallback onAdd;
  final void Function(int) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        ...rows.asMap().entries.map((entry) {
          final idx = entry.key;
          final row = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  ...schema.keys.map((key) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextFormField(
                          controller: row[key],
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: key,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return '$key is required';
                            }
                            if (double.tryParse(v.trim()) == null) {
                              return 'Enter a number';
                            }
                            return null;
                          },
                        ),
                      )),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: rows.length > 1 ? () => onRemove(idx) : null,
                      icon: const Icon(Icons.remove_circle_outline, size: 16),
                      label: const Text('Remove'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.destructive),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (canAdd)
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: Text('Add $label'),
          ),
      ],
    );
  }
}

// ── Field help dialog ─────────────────────────────────────────────────────────

void _showFieldHelpDialog(
  BuildContext context,
  String label,
  String? tooltip,
  String? hint,
  String? typicalRange,
) {
  showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.cs.backgroundSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF19CBD6).withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline,
                    color: Color(0xFF19CBD6), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.cs.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            if (tooltip != null && tooltip.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                tooltip,
                style: TextStyle(
                  fontSize: 13,
                  color: context.cs.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
            if (hint != null && hint.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      size: 14, color: Color(0xFFD97D24)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hint,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.cs.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (typicalRange != null && typicalRange.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF19CBD6).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.straighten,
                        size: 13, color: Color(0xFF19CBD6)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Typical range: $typicalRange',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF19CBD6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
