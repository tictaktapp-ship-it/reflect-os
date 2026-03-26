import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';
import 'package:reflect_os/features/initiatives/providers/initiatives_provider.dart';
import 'package:reflect_os/core/theme/app_radius.dart';

class CreateInitiativeScreen extends ConsumerStatefulWidget {
  const CreateInitiativeScreen({super.key});

  @override
  ConsumerState<CreateInitiativeScreen> createState() =>
      _CreateInitiativeScreenState();
}

class _CreateInitiativeScreenState
    extends ConsumerState<CreateInitiativeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<String> _selectedDecisionIds = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final workspaceId = ref.read(currentWorkspaceProvider).valueOrNull;
    if (workspaceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workspace not available. Try again.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final description = _descriptionController.text.trim();
      final repo = ref.read(initiativesRepositoryProvider);

      final initiativeId = await repo.createInitiative(
        name: _nameController.text.trim(),
        workspaceId: workspaceId,
        description: description.isEmpty ? null : description,
      );

      if (_selectedDecisionIds.isNotEmpty) {
        await repo.linkDecisionsToInitiative(
          initiativeId: initiativeId,
          decisionIds: _selectedDecisionIds,
        );
      }

      ref.invalidate(initiativesProvider);
      if (mounted) Navigator.of(context).pop();
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

  void _showDecisionPicker(List<Decision> allDecisions) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.sheetTop,
      ),
      builder: (_) => _DecisionPickerSheet(
        allDecisions: allDecisions,
        selectedIds: List<String>.from(_selectedDecisionIds),
        onDone: (selected) => setState(() {
          _selectedDecisionIds
            ..clear()
            ..addAll(selected);
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final decisionsAsync = ref.watch(decisionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Initiative'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Initiative name',
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Optional description',
                alignLabelWithHint: true,
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
            ),

            // ── Link decisions ────────────────────────────────────────────
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'Link decisions',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add linked decisions',
                  onPressed: decisionsAsync.valueOrNull != null
                      ? () => _showDecisionPicker(decisionsAsync.value!)
                      : null,
                ),
              ],
            ),

            // Selected chips
            if (_selectedDecisionIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              decisionsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (all) {
                  final selected = all
                      .where((d) => _selectedDecisionIds.contains(d.id))
                      .toList();
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selected
                        .map((d) => Chip(
                              label: Text(d.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () => setState(
                                  () => _selectedDecisionIds.remove(d.id)),
                            ))
                        .toList(),
                  );
                },
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                'No decisions linked yet',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5)),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Decision picker bottom sheet ────────────────────────────────────────────────

class _DecisionPickerSheet extends StatefulWidget {
  const _DecisionPickerSheet({
    required this.allDecisions,
    required this.selectedIds,
    required this.onDone,
  });

  final List<Decision> allDecisions;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onDone;

  @override
  State<_DecisionPickerSheet> createState() => _DecisionPickerSheetState();
}

class _DecisionPickerSheetState extends State<_DecisionPickerSheet> {
  late final List<String> _selected;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.selectedIds);
    _searchController.addListener(
        () => setState(() => _query = _searchController.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Decision> get _filtered {
    if (_query.isEmpty) return widget.allDecisions;
    return widget.allDecisions
        .where((d) => d.title.toLowerCase().contains(_query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.25),
                borderRadius: AppRadius.xsBR,
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Text('Link decisions',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    widget.onDone(_selected);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search decisions…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.smBR,
                ),
              ),
            ),
          ),

          // List
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text('No decisions found',
                        style: Theme.of(context).textTheme.bodySmall))
                : ListView.builder(
                    controller: scrollController,
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      final d = _filtered[i];
                      final isSelected = _selected.contains(d.id);
                      return InkWell(
                        onTap: () => setState(() {
                          if (isSelected) {
                            _selected.remove(d.id);
                          } else {
                            _selected.add(d.id);
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.smBR,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.accentPrimary
                                  : Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withValues(alpha: 0.3),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  d.title,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: isSelected
                                    ? AppColors.accentPrimary
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.3),
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
