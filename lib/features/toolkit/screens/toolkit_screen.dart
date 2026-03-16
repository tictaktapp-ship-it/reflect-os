import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/routing/routes.dart';
import '../data/models/tool_definition.dart';
import '../providers/toolkit_providers.dart';
import '../widgets/tool_card.dart';

/// Browse all available Tool Kit tools, optionally scoped to a decision.
///
/// When [decisionId] is provided the tool detail screen will tie the run
/// to that decision.
///
/// When [pickerMode] is true (via Routes.toolkitPicker) the screen shows a
/// banner and awaits tool output, then pops the result back to the caller.
class ToolkitScreen extends ConsumerStatefulWidget {
  const ToolkitScreen({
    super.key,
    this.decisionId,
    this.pickerMode = false,
  });

  final String? decisionId;
  final bool pickerMode;

  @override
  ConsumerState<ToolkitScreen> createState() => _ToolkitScreenState();
}

class _ToolkitScreenState extends ConsumerState<ToolkitScreen> {
  String _query = '';
  String? _readOnlyResult;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra is Map<String, dynamic>) {
      _readOnlyResult = extra['readOnlyResult'] as String?;
    }
  }

  @override
  Widget build(BuildContext context) {
    final toolsAsync = ref.watch(toolDefinitionsProvider);
    final theme = Theme.of(context);

    // ── Read-only result view ──────────────────────────────────────────────
    if (_readOnlyResult != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Projected Outcome')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: theme.colorScheme.primaryContainer,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline,
                      size: 16,
                      color: theme.colorScheme.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Text(
                    'Viewing attached projected outcome',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _readOnlyResult!,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Normal / picker mode view ──────────────────────────────────────────
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tool Kit'),
        actions: const [],
      ),
      body: Column(
        children: [
          // ── Picker mode banner ──────────────────────────────────
          if (widget.pickerMode)
            Container(
              width: double.infinity,
              color: theme.colorScheme.primaryContainer,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'Run a tool, then tap "Attach this output" to attach it to your decision',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),

          // ── Search field ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search tools…',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.borderSubtle),
                ),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          const SizedBox(height: 8),

          // ── Tool list ───────────────────────────────────────────
          Expanded(
            child: toolsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Could not load tools: ${error.toString()}'),
              ),
              data: (tools) {
                final filtered = _query.isEmpty
                    ? tools
                    : tools
                        .where((t) =>
                            t.name.toLowerCase().contains(_query) ||
                            t.description.toLowerCase().contains(_query) ||
                            t.category.toLowerCase().contains(_query))
                        .toList();

                if (filtered.isEmpty) {
                  return const Center(
                      child: Text('No tools match your search.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => ToolCard(
                    tool: filtered[index],
                    onTap: () => _openTool(filtered[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTool(ToolDefinition tool) async {
    final base = Routes.toolDetail.replaceFirst(':toolId', tool.id);
    final params = <String>[
      if (widget.decisionId != null) 'decisionId=${widget.decisionId}',
      if (widget.pickerMode) 'pickerMode=true',
    ];
    final path = params.isNotEmpty ? '$base?${params.join('&')}' : base;

    if (widget.pickerMode) {
      debugPrint('TOOLKIT PICKER: opening tool "${tool.name}" at $path');
      final result = await context.push<String?>(path, extra: tool);
      debugPrint('TOOLKIT PICKER: tool returned result: "$result"');
      if (result != null && result.isNotEmpty && mounted) {
        // Propagate the output back to the decision form.
        context.pop(result);
      }
    } else {
      context.push(path, extra: tool);
    }
  }
}
