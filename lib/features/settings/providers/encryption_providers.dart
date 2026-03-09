import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import '../data/encryption_settings_repository.dart';
import '../data/models/encryption_settings.dart';

final encryptionSettingsRepositoryProvider =
    Provider<EncryptionSettingsRepository>(
  (_) => const EncryptionSettingsRepository(),
);

/// Returns the encryption settings for a workspace, or null when no DB row
/// exists (meaning the workspace uses the default: encrypted).
final encryptionSettingsProvider =
    FutureProvider.family<EncryptionSettings?, String>((ref, workspaceId) {
  return ref
      .read(encryptionSettingsRepositoryProvider)
      .getSettings(workspaceId);
});

/// Returns 'encrypted' or 'plaintext' for the current workspace.
/// Defaults to 'encrypted' when no setting exists.
final workspaceEncryptionModeProvider = FutureProvider<String?>((ref) async {
  final workspaceId = await ref.watch(currentWorkspaceProvider.future);
  if (workspaceId == null) return null;
  final settings = await ref
      .read(encryptionSettingsRepositoryProvider)
      .getSettings(workspaceId);
  return settings?.mode == EncryptionMode.plaintext ? 'plaintext' : 'encrypted';
});
