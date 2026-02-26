import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/features/templates/data/models/decision_template.dart';
import 'package:reflect_os/features/templates/data/templates_repository.dart';

final templatesRepositoryProvider = Provider<TemplatesRepository>(
  (ref) => const TemplatesRepository(),
);

final templatesProvider = FutureProvider<List<DecisionTemplate>>((ref) async {
  final workspaceId = await ref.watch(currentWorkspaceProvider.future);
  if (workspaceId == null) return [];
  return ref.read(templatesRepositoryProvider).getTemplates(workspaceId);
});
