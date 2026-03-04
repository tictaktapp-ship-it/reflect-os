import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/toolkit_repository.dart';
import '../data/models/tool_definition.dart';
import '../data/models/tool_run.dart';

final toolkitRepositoryProvider = Provider<ToolkitRepository>(
  (_) => const ToolkitRepository(),
);

final toolDefinitionsProvider =
    FutureProvider<List<ToolDefinition>>((ref) {
  return ref.watch(toolkitRepositoryProvider).getToolDefinitions();
});

final decisionToolRunsProvider =
    FutureProvider.family<List<ToolRun>, String>((ref, decisionId) {
  return ref
      .watch(toolkitRepositoryProvider)
      .getToolRunsForDecision(decisionId);
});
