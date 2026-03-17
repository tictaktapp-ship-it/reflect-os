import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';

/// Reads `ai_features_enabled` from `workspace_settings` for the given
/// workspace. Returns `true` (AI enabled) when the row is absent or the
/// query fails, so the feature is never accidentally hidden.
final workspaceAiSettingProvider =
    FutureProvider.family<bool, String>((ref, workspaceId) async {
  try {
    final row = await supabase
        .from('workspace_settings')
        .select('ai_features_enabled')
        .eq('workspace_id', workspaceId)
        .maybeSingle();
    return row?['ai_features_enabled'] as bool? ?? true;
  } catch (_) {
    return true;
  }
});

/// Whether AI features are enabled for the **current** workspace.
/// Defaults to `true` when the setting cannot be loaded.
final workspaceAiEnabledProvider = FutureProvider<bool>((ref) async {
  final workspaceId = await ref.watch(currentWorkspaceProvider.future);
  if (workspaceId == null) return true;
  return ref.watch(workspaceAiSettingProvider(workspaceId)).valueOrNull ?? true;
});
