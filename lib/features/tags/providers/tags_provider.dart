import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/features/tags/data/models/tag.dart';
import 'package:reflect_os/features/tags/data/tags_repository.dart';

final tagsRepositoryProvider = Provider<TagsRepository>(
  (ref) => const TagsRepository(),
);

/// All tags for the current workspace, ordered by name.
final workspaceTagsProvider = FutureProvider<List<Tag>>((ref) async {
  final workspaceId = await ref.watch(currentWorkspaceProvider.future);
  if (workspaceId == null) return [];
  return ref.read(tagsRepositoryProvider).getTagsForWorkspace(workspaceId);
});

/// Tags linked to a specific decision.
final decisionTagsProvider =
    FutureProvider.family<List<Tag>, String>((ref, decisionId) {
  return ref.read(tagsRepositoryProvider).getTagsForDecision(decisionId);
});
