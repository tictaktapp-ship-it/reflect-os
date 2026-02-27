import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/features/settings/data/models/vertical_config.dart';
import 'package:reflect_os/features/settings/data/vertical_repository.dart';

final verticalRepositoryProvider = Provider<VerticalRepository>(
  (_) => const VerticalRepository(),
);

/// All available verticals, ordered by name.
final verticalsProvider = FutureProvider<List<VerticalConfig>>((ref) {
  return ref.read(verticalRepositoryProvider).getVerticals();
});

/// The VerticalConfig currently selected for the active workspace.
final currentVerticalProvider = FutureProvider<VerticalConfig?>((ref) async {
  final workspaceId = await ref.watch(currentWorkspaceProvider.future);
  if (workspaceId == null) return null;
  return ref
      .read(verticalRepositoryProvider)
      .getCurrentVertical(workspaceId);
});

// ── StateNotifier for persisting the selected vertical name ───────────────────

class SelectedVerticalNotifier extends StateNotifier<String> {
  SelectedVerticalNotifier() : super('general');

  Future<void> setVertical(String name, String workspaceId) async {
    state = name;
    await const VerticalRepository().setVertical(workspaceId, name);
  }
}

final selectedVerticalNotifierProvider =
    StateNotifierProvider<SelectedVerticalNotifier, String>(
  (_) => SelectedVerticalNotifier(),
);
