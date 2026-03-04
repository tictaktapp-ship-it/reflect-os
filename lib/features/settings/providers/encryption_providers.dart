import 'package:flutter_riverpod/flutter_riverpod.dart';
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
