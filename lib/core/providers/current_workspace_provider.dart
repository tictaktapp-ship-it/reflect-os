import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/providers/auth_state_provider.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/workspace/providers/workspace_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLastWorkspaceKey = 'last_workspace_id';

/// Provides the current user's active workspace_id.
/// Priority: explicit user selection → last-used (SharedPreferences) →
/// first team workspace → first workspace.
/// Kept as `FutureProvider<String?>` for backward compat with existing callers.
final currentWorkspaceProvider = FutureProvider<String?>((ref) async {
  final authStatus = ref.watch(authStateProvider);
  if (authStatus.valueOrNull is! AuthAuthenticated) return null;

  final selectedId = ref.watch(selectedWorkspaceIdProvider);
  if (selectedId != null) return selectedId;

  final workspaces = await ref.watch(userWorkspacesProvider.future);
  if (workspaces.isEmpty) return null;

  final prefs = await SharedPreferences.getInstance();
  final lastId = prefs.getString(_kLastWorkspaceKey);
  if (lastId != null && workspaces.any((w) => w.id == lastId)) return lastId;

  // Prefer first team workspace ordered by joinedAt ascending.
  final teamWorkspaces = workspaces
      .where((w) => w.workspaceType == 'team')
      .toList()
    ..sort((a, b) {
      final aDate = a.joinedAt ?? DateTime(2000);
      final bDate = b.joinedAt ?? DateTime(2000);
      return aDate.compareTo(bDate);
    });
  if (teamWorkspaces.isNotEmpty) return teamWorkspaces.first.id;

  // No team workspace — pick personal workspace with the most decisions.
  // Never default to an empty workspace if a non-empty one exists.
  final candidates = workspaces.toList();
  if (candidates.length == 1) return candidates.first.id;

  try {
    final counts = <String, int>{};
    for (final ws in candidates) {
      final rows = await supabase
          .from('user_visible_decisions')
          .select('id')
          .eq('workspace_id', ws.id);
      counts[ws.id] = rows.length;
    }
    candidates.sort(
        (a, b) => (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0));
    return candidates.first.id;
  } catch (_) {
    return candidates.first.id;
  }
});

/// Call this whenever the user explicitly switches workspace so the choice
/// persists across app restarts.
Future<void> persistWorkspaceSelection(String workspaceId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kLastWorkspaceKey, workspaceId);
}

/// Provides the display name of the current workspace.
/// Falls back to 'My Workspace' if the workspace cannot be found.
final workspaceNameProvider = FutureProvider<String?>((ref) async {
  final workspaceId = await ref.watch(currentWorkspaceProvider.future);
  if (workspaceId == null) return null;

  final workspaces = await ref.watch(userWorkspacesProvider.future);
  try {
    return workspaces.firstWhere((w) => w.id == workspaceId).name;
  } catch (_) {
    return 'My Workspace';
  }
});
