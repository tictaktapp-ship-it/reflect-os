import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/features/decisions/data/models/audit_event.dart';
import 'package:reflect_os/features/settings/data/models/notification_preferences.dart';
import 'package:reflect_os/features/settings/data/models/workspace_branding.dart';
import 'package:reflect_os/features/settings/data/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (_) => const SettingsRepository(),
);

final auditLogProvider = FutureProvider<List<AuditEvent>>((ref) async {
  final workspaceId = await ref.watch(currentWorkspaceProvider.future);
  if (workspaceId == null) return [];
  return ref.read(settingsRepositoryProvider).getAuditLog(workspaceId);
});

final notificationPreferencesProvider =
    FutureProvider<NotificationPreferences?>((ref) {
  return ref.read(settingsRepositoryProvider).getNotificationPreferences();
});

final workspaceBrandingProvider =
    FutureProvider<WorkspaceBranding?>((ref) async {
  final workspaceId = await ref.watch(currentWorkspaceProvider.future);
  if (workspaceId == null) return null;
  return ref
      .read(settingsRepositoryProvider)
      .getWorkspaceBranding(workspaceId);
});
