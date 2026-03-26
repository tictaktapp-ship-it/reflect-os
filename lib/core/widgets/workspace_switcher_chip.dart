import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/features/workspace/data/models/workspace_model.dart';
import 'package:reflect_os/features/workspace/providers/workspace_providers.dart';
import 'package:reflect_os/core/theme/app_radius.dart';

// Helper to get current workspace model
final _currentWorkspaceModelProvider = FutureProvider<WorkspaceModel?>((ref) async {
  final workspaces = ref.watch(userWorkspacesProvider).valueOrNull ?? [];
  final currentId = ref.watch(currentWorkspaceProvider).valueOrNull;
  if (currentId == null) return null;
  try {
    return workspaces.firstWhere((w) => w.id == currentId);
  } catch (_) {
    return null;
  }
});

IconData _workspaceTypeIcon(String? type) => switch (type) {
      'personal' => Icons.person,
      'team' => Icons.group,
      'coach' => Icons.psychology,
      _ => Icons.person,
    };

/// Opens the workspace switcher dialog (centered).
/// Extracted as a top-level function so it can be reused across screens.
void showWorkspaceSwitcherSheet(BuildContext context, WidgetRef ref) {
  final workspaces = ref.read(userWorkspacesProvider).valueOrNull ?? [];
  final currentId = ref.read(currentWorkspaceProvider).valueOrNull;

  showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (dialogCtx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 360,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppRadius.xlBR,
            border: Border.all(color: const Color(0xFF19CBD6), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: SvgPicture.asset(
                  'assets/branding/icon.svg',
                  height: 48,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Switch Workspace',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              ...workspaces.map(
                (w) => ListTile(
                  leading: Icon(
                    _workspaceTypeIcon(w.workspaceType),
                    color: const Color(0xFF19CBD6),
                  ),
                  title: Text(w.name),
                  trailing: w.id == currentId
                      ? const Icon(Icons.check, color: Color(0xFF19CBD6))
                      : null,
                  onTap: () {
                    ref.read(selectedWorkspaceIdProvider.notifier).state = w.id;
                    persistWorkspaceSelection(w.id);
                    Navigator.of(dialogCtx).pop();
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.add, color: Color(0xFF19CBD6)),
                title: const Text('New workspace'),
                onTap: () {
                  Navigator.of(dialogCtx).pop();
                  context.push(Routes.settingsWorkspaces);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    },
  );
}

class WorkspaceSwitcherChip extends ConsumerWidget {
  const WorkspaceSwitcherChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceName = ref.watch(workspaceNameProvider).valueOrNull;
    final workspaceModel = ref.watch(_currentWorkspaceModelProvider).valueOrNull;
    final typeIcon = _workspaceTypeIcon(workspaceModel?.workspaceType);

    return GestureDetector(
      onTap: () => showWorkspaceSwitcherSheet(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.accentPrimary.withValues(alpha: 0.12),
          borderRadius: AppRadius.pillBR,
          border: Border.all(color: AppColors.accentPrimary, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(typeIcon, size: 14, color: AppColors.accentPrimary),
            const SizedBox(width: 6),
            Text(
              workspaceName ?? 'Select workspace',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.accentPrimary,
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 16, color: AppColors.accentPrimary),
          ],
        ),
      ),
    );
  }
}
