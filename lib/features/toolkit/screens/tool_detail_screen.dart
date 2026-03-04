import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/routing/routes.dart';
import '../data/models/tool_definition.dart';
import '../data/models/tool_field.dart';
import '../data/toolkit_repository.dart';
import '../engine/calculator_engine.dart';

/// Tool input form. Collects user inputs, runs the calculator engine,
/// persists outputs via two-call RPC flow, then navigates to results.
class ToolDetailScreen extends ConsumerStatefulWidget {
  const ToolDetailScreen({
    super.key,
    required this.toolId,
    this.decisionId,
    this.tool,
  });

  final String toolId;
  final String? decisionId;

  /// Passed as [GoRouterState.extra] from the browse screen to avoid a
  /// redundant DB fetch.
  final ToolDefinition? tool;

  @override
  ConsumerState<ToolDetailScreen> createState() => _ToolDetailScreenState();
}

class _ToolDetailScreenState extends ConsumerState<ToolDetailScreen> {
  final _formKey = GlobalKey<FormState>();

  /// Stores raw field values keyed by field id.
  /// Numbers are stored as strings from TextFormField and parsed on run.
  final Map<String, dynamic> _fieldValues = {};

  /// For array-of-objects fields (e.g. weighted_score criteria) we keep a
  /// list of per-row controllers.
  final Map<String, List<Map<String, TextEditingController>>>
      _objectRowControllers = {};

  bool _running = false;

  ToolDefinition? get _tool => widget.tool;

  @override
  void initState() {
    super.initState();
    _initDefaults();
  }

  void _initDefaults() {
    final tool = _tool;
    if (tool == null) return;
    for (final f in tool.inputSchema) {
      if (f.defaultValue != null) {
        _fieldValues[f.id] = f.defaultValue.toString();
      }
      if (f.type == 'array' && f.itemType == 'object') {
        _objectRowControllers[f.id] = [];
        _addObjectRow(f.id, f.itemSchema ?? {});
      }
    }
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

  Future<void> _run() async {
    if (!_formKey.currentState!.validate()) return;

    final tool = _tool;
    if (tool == null) return;

    final workspaceId = ref.read(currentWorkspaceProvider).valueOrNull;
    if (workspaceId == null) {
      _showError('No active workspace found.');
      return;
    }

    final decisionId = widget.decisionId;
    if (decisionId == null) {
      _showError('This tool must be opened from a decision.');
      return;
    }

    setState(() => _running = true);
    try {
      final inputs = _collectInputs(tool);

      // Step 1: create shell run row
      final repo = const ToolkitRepository();
      final toolRunId = await repo.runTool(
        workspaceId: workspaceId,
        decisionId: decisionId,
        toolDefinitionId: tool.id,
        inputsJsonb: inputs,
      );

      // Step 2: compute outputs (pure Dart, no network)
      final engine = const CalculatorEngine();
      final outputs = engine.compute(tool.formulaAst, inputs);

      // Step 3: persist outputs
      await repo.approveAndInjectToolOutput(
        toolRunId: toolRunId,
        outputsJsonb: outputs,
      );

      if (!mounted) return;

      final resultsPath =
          Routes.toolResults.replaceFirst(':toolId', tool.id);
      context.push(
        resultsPath,
        extra: {
          'toolRunId': toolRunId,
          'outputs': outputs,
          'tool': tool,
          'decisionId': decisionId,
        },
      );
    } catch (e) {
      _showError('Failed to run tool: $e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Map<String, dynamic> _collectInputs(ToolDefinition tool) {
    final inputs = <String, dynamic>{};
    for (final f in tool.inputSchema) {
      if (f.type == 'number') {
        final raw = (_fieldValues[f.id] as String? ?? '').trim();
        inputs[f.id] = double.tryParse(raw) ?? 0.0;
      } else if (f.type == 'text') {
        inputs[f.id] = (_fieldValues[f.id] as String? ?? '').trim();
      } else if (f.type == 'array' && f.itemType == 'number') {
        final raw = (_fieldValues[f.id] as String? ?? '');
        inputs[f.id] = raw
            .split(',')
            .map((s) => double.tryParse(s.trim()) ?? 0.0)
            .toList();
      } else if (f.type == 'array' && f.itemType == 'object') {
        final rows = _objectRowControllers[f.id] ?? [];
        inputs[f.id] = rows.map((row) {
          return row.map(
            (key, ctrl) =>
                MapEntry(key, double.tryParse(ctrl.text.trim()) ?? 0.0),
          );
        }).toList();
      }
    }
    return inputs;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

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
      appBar: AppBar(title: Text(tool.name)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              tool.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),
            ...tool.inputSchema.map((f) => _buildField(f)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _running ? null : _run,
                child: _running
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Run'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(ToolInputField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: switch (field.type) {
        'number' => _NumberField(
            field: field,
            initialValue:
                _fieldValues[field.id] as String?,
            onChanged: (v) => _fieldValues[field.id] = v,
          ),
        'text' => _TextField(
            field: field,
            initialValue:
                _fieldValues[field.id] as String?,
            onChanged: (v) => _fieldValues[field.id] = v,
          ),
        'array' when field.itemType == 'number' => _NumberArrayField(
            field: field,
            initialValue:
                _fieldValues[field.id] as String?,
            onChanged: (v) => _fieldValues[field.id] = v,
          ),
        'array' when field.itemType == 'object' =>
          _ObjectArrayField(
            field: field,
            rows: _objectRowControllers[field.id] ?? [],
            onAdd: () =>
                _addObjectRow(field.id, field.itemSchema ?? {}),
            onRemove: (i) => _removeObjectRow(field.id, i),
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

// ── Input field widgets ────────────────────────────────────────────────────────

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.field,
    required this.initialValue,
    required this.onChanged,
  });

  final ToolInputField field;
  final String? initialValue;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: InputDecoration(
        labelText: field.unit != null
            ? '${field.label} (${field.unit})'
            : field.label,
        hintText: field.hint,
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        if (field.required && (v == null || v.trim().isEmpty)) {
          return '${field.label} is required';
        }
        if (v != null && v.trim().isNotEmpty) {
          if (double.tryParse(v.trim()) == null) return 'Enter a number';
        }
        return null;
      },
      onChanged: onChanged,
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.field,
    required this.initialValue,
    required this.onChanged,
  });

  final ToolInputField field;
  final String? initialValue;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.hint,
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        if (field.required && (v == null || v.trim().isEmpty)) {
          return '${field.label} is required';
        }
        return null;
      },
      onChanged: onChanged,
    );
  }
}

class _NumberArrayField extends StatelessWidget {
  const _NumberArrayField({
    required this.field,
    required this.initialValue,
    required this.onChanged,
  });

  final ToolInputField field;
  final String? initialValue;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.hint ?? 'e.g. 1000, 2000, 3000',
        helperText: 'Comma-separated numbers',
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        if (field.required && (v == null || v.trim().isEmpty)) {
          return '${field.label} is required';
        }
        if (v != null && v.trim().isNotEmpty) {
          final parts = v.split(',');
          for (final p in parts) {
            if (double.tryParse(p.trim()) == null) {
              return 'Each value must be a number';
            }
          }
        }
        return null;
      },
      onChanged: onChanged,
    );
  }
}

class _ObjectArrayField extends StatelessWidget {
  const _ObjectArrayField({
    required this.field,
    required this.rows,
    required this.onAdd,
    required this.onRemove,
  });

  final ToolInputField field;
  final List<Map<String, TextEditingController>> rows;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final schema = field.itemSchema ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        ...rows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  ...schema.keys.map((key) {
                    final ctrl = row[key]!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextFormField(
                        controller: ctrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
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
                    );
                  }),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: rows.length > 1
                          ? () => onRemove(index)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline, size: 16),
                      label: const Text('Remove'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.destructive,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 16),
          label: Text('Add ${field.label}'),
        ),
      ],
    );
  }
}
