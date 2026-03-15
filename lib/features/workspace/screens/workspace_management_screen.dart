import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/widgets/app_header.dart';
import 'package:reflect_os/widgets/dialog_shell.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/features/workspace/data/models/workspace_model.dart';
import 'package:reflect_os/features/workspace/providers/workspace_providers.dart';

class WorkspaceManagementScreen extends ConsumerStatefulWidget {
  const WorkspaceManagementScreen({super.key});

  @override
  ConsumerState<WorkspaceManagementScreen> createState() =>
      _WorkspaceManagementScreenState();
}

class _WorkspaceManagementScreenState
    extends ConsumerState<WorkspaceManagementScreen> {
  bool _isWorking = false;

  // ── Create ────────────────────────────────────────────────────────────────

  void _showCreateSheet() {
    final nameCtrl = TextEditingController();
    bool shareWithTeam = false;
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DialogShell(
          title: 'New Workspace',
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Workspace name *'),
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name required' : null,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Share with team'),
                  subtitle: const Text('Creates a team workspace'),
                  value: shareWithTeam,
                  onChanged: (v) => setSheetState(() => shareWithTeam = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final name = nameCtrl.text.trim();
                Navigator.of(ctx).pop();
                await _createWorkspace(name, shareWithTeam);
              },
              child: const Text('Create Workspace'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createWorkspace(String name, bool shareWithTeam) async {
    setState(() => _isWorking = true);
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .createWorkspace(name, shareWithTeam);
      ref.invalidate(userWorkspacesProvider);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Workspace "$name" created')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create workspace: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  // ── Rename ────────────────────────────────────────────────────────────────

  Future<void> _showRenameDialog(WorkspaceModel workspace) async {
    final controller = TextEditingController(text: workspace.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => DialogShell(
        title: 'Rename Workspace',
        child: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Workspace name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty || !mounted) return;
    setState(() => _isWorking = true);
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .renameWorkspace(workspace.id, result);
      ref.invalidate(userWorkspacesProvider);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rename: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(WorkspaceModel workspace) async {
    final currentId = ref.read(currentWorkspaceProvider).valueOrNull;
    if (workspace.id == currentId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot delete the active workspace. Switch to another first.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => DialogShell(
        title: 'Delete Workspace',
        child: Text(
          'Delete "${workspace.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: AppColors.destructive),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isWorking = true);
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .deleteWorkspace(workspace.id);
      ref.invalidate(userWorkspacesProvider);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete workspace: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final workspacesAsync = ref.watch(userWorkspacesProvider);
    final currentId = ref.watch(currentWorkspaceProvider).valueOrNull;

    return Scaffold(
      appBar: AppHeader(
        title: 'Workspaces',
        actions: [
          if (_isWorking)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isWorking ? null : _showCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('New Workspace'),
      ),
      body: workspacesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load workspaces: $e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (workspaces) {
          if (workspaces.isEmpty) {
            return const Center(child: Text('No workspaces found.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: workspaces.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final w = workspaces[i];
              final isActive = w.id == currentId;
              final isOwner = w.role == 'owner';
              return Card(
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              w.name,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          if (isActive)
                            _Badge(
                              label: 'Active',
                              color: AppColors.accentPrimary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _Badge(
                            label: isOwner ? 'Owner' : 'Member',
                            color: isOwner
                                ? AppColors.accentPrimary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 6),
                          _Badge(
                            label: w.workspaceType == 'team'
                                ? 'Team'
                                : 'Personal',
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.35),
                          ),
                        ],
                      ),
                      if (isOwner) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Rename'),
                              onPressed: _isWorking
                                  ? null
                                  : () => _showRenameDialog(w),
                              visualDensity: VisualDensity.compact,
                            ),
                            ActionChip(
                              avatar: Icon(
                                Icons.delete_outlined,
                                size: 16,
                                color: AppColors.destructive,
                              ),
                              label: Text(
                                'Delete',
                                style: TextStyle(
                                    color: AppColors.destructive),
                              ),
                              onPressed:
                                  _isWorking ? null : () => _confirmDelete(w),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
