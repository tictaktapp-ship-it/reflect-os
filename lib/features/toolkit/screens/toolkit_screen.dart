import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/widgets/workspace_switcher_chip.dart';
import '../data/models/tool_definition.dart';
import '../providers/toolkit_providers.dart';
import '../widgets/tool_card.dart';

/// Browse all available Tool Kit tools, optionally scoped to a decision.
///
/// When [decisionId] is provided the tool detail screen will tie the run
/// to that decision.
///
/// When opened via `context.push(Routes.toolkit, extra: {'pickerMode': true})`
/// the screen enters picker mode: a banner is shown and each tool card gets
/// an "Attach this" button that pops the tool name back to the caller.
class ToolkitScreen extends ConsumerStatefulWidget {
  const ToolkitScreen({super.key, this.decisionId});

  final String? decisionId;

  @override
  ConsumerState<ToolkitScreen> createState() => _ToolkitScreenState();
}

class _ToolkitScreenState extends ConsumerState<ToolkitScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final toolsAsync = ref.watch(toolDefinitionsProvider);
    final theme = Theme.of(context);

    // Picker mode: opened from decision form to select a projected outcome.
    final extra = GoRouterState.of(context).extra;
    final bool pickerMode = extra is Map && extra['pickerMode'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tool Kit'),
        actions: const [WorkspaceSwitcherChip(), SizedBox(width: 8)],
      ),
      body: Column(
        children: [
          // ── Picker mode banner ──────────────────────────────────
          if (pickerMode)
            Container(
              width: double.infinity,
              color: theme.colorScheme.primaryContainer,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'Select a projected outcome to attach to your decision',
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
                  itemBuilder: (context, index) {
                    final tool = filtered[index];
                    // In picker mode, navigate into the tool so the user
                    // can run it and attach the actual output text.
                    return ToolCard(
                      tool: tool,
                      onTap: () => _openTool(tool, pickerMode: pickerMode),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openTool(ToolDefinition tool, {bool pickerMode = false}) {
    final base = Routes.toolDetail.replaceFirst(':toolId', tool.id);
    final params = <String>[
      if (widget.decisionId != null) 'decisionId=${widget.decisionId}',
      if (pickerMode) 'pickerMode=true',
    ];
    final path = params.isNotEmpty ? '$base?${params.join('&')}' : base;
    context.push(path, extra: tool);
  }
}
