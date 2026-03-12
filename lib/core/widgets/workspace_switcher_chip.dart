import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/features/workspace/providers/workspace_providers.dart';

/// Opens the workspace switcher bottom sheet.
/// Extracted as a top-level function so it can be reused across screens.
void showWorkspaceSwitcherSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) {
      final workspaces = ref.read(userWorkspacesProvider).valueOrNull ?? [];
      final currentId = ref.read(currentWorkspaceProvider).valueOrNull;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Switch Workspace',
                style: Theme.of(sheetCtx).textTheme.titleMedium,
              ),
            ),
            ...workspaces.map(
              (w) => ListTile(
                leading: const Icon(Icons.business),
                title: Text(w.name),
                trailing: w.id == currentId
                    ? const Icon(Icons.check, color: AppColors.accentPrimary)
                    : null,
                onTap: () {
                  ref.read(selectedWorkspaceIdProvider.notifier).state = w.id;
                  Navigator.of(sheetCtx).pop();
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New workspace'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                context.push(Routes.settingsWorkspaces);
              },
            ),
            const SizedBox(height: 8),
          ],
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
    return GestureDetector(
      onTap: () => showWorkspaceSwitcherSheet(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.accentPrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accentPrimary, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.business, size: 14, color: AppColors.accentPrimary),
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
