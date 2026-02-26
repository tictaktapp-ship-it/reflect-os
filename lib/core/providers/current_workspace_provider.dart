import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/providers/auth_state_provider.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';

/// Provides the current user's workspace_id.
/// Exception to the no-raw-tables rule: there is no user_visible_workspaces
/// view exposed to Flutter. The subscriptions table is queried directly here.
/// RLS on the subscriptions table ensures users can only read their own row.
final currentWorkspaceProvider = FutureProvider<String?>((ref) async {
  final authStatus = ref.watch(authStateProvider);
  final auth = authStatus.valueOrNull;

  if (auth is! AuthAuthenticated) return null;

  final userId = auth.session.user.id;

  final response = await supabase
      .from('subscriptions')
      .select('workspace_id')
      .eq('user_id', userId)
      .maybeSingle();

  return response?['workspace_id'] as String?;
});

/// Reads the workspace name from the workspaces table.
/// Exception to the no-raw-tables rule: there is no user_visible_workspaces view.
/// RLS on the workspaces table ensures the user can only read their own workspace.
final workspaceNameProvider = FutureProvider<String?>((ref) async {
  final workspaceId = await ref.watch(currentWorkspaceProvider.future);
  if (workspaceId == null) return null;

  final row = await supabase
      .from('workspaces')
      .select('name')
      .eq('id', workspaceId)
      .maybeSingle();

  return row?['name'] as String?;
});
