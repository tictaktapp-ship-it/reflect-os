import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/features/templates/data/models/decision_template.dart';
import 'package:reflect_os/features/templates/providers/templates_provider.dart';

class TemplatesScreen extends ConsumerStatefulWidget {
  const TemplatesScreen({super.key});

  @override
  ConsumerState<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends ConsumerState<TemplatesScreen> {
  bool _isWorking = false;

  // ── Create ──────────────────────────────────────────────────────────────────

  void _showCreateSheet() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? stakes;
    bool requiresApproval = false;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              20,
              16,
              MediaQuery.of(ctx).viewInsets.bottom + 32,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: SvgPicture.asset(
                      isDark
                          ? 'assets/images/reflect-icon-dark.svg'
                          : 'assets/images/reflect-icon-light.svg',
                      height: 128,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'New Template',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name *'),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Name required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3,
                    minLines: 2,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: stakes,
                    decoration: const InputDecoration(labelText: 'Default Stakes'),
                    hint: const Text('None'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('None')),
                      DropdownMenuItem(value: 'Low', child: Text('Low')),
                      DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'High', child: Text('High')),
                      DropdownMenuItem(
                          value: 'Critical', child: Text('Critical')),
                    ],
                    onChanged: (v) => setSheetState(() => stakes = v),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Requires Approval'),
                    value: requiresApproval,
                    onChanged: (v) =>
                        setSheetState(() => requiresApproval = v),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _isWorking
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            Navigator.of(ctx).pop();
                            await _createTemplate(
                              name: nameCtrl.text.trim(),
                              description: descCtrl.text.trim(),
                              defaultStakes: stakes,
                              requiresApproval: requiresApproval,
                            );
                          },
                    child: const Text('Create Template'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _createTemplate({
    required String name,
    required String description,
    String? defaultStakes,
    required bool requiresApproval,
  }) async {
    setState(() => _isWorking = true);
    try {
      final workspaceId = await ref.read(currentWorkspaceProvider.future);
      if (workspaceId == null) return;
      await ref.read(templatesRepositoryProvider).createTemplate(
            workspaceId: workspaceId,
            name: name,
            description: description.isEmpty ? null : description,
            defaultStakes: defaultStakes,
            requiresApproval: requiresApproval,
          );
      ref.invalidate(templatesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create template: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  // ── Delete ──────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(DecisionTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text(
            'Delete "${template.name}"? This cannot be undone.'),
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
    if (confirmed != true) return;
    setState(() => _isWorking = true);
    try {
      await ref
          .read(templatesRepositoryProvider)
          .deleteTemplate(template.id);
      ref.invalidate(templatesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete template: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  // ── Detail sheet ────────────────────────────────────────────────────────────

  void _showDetail(DecisionTemplate template) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              Center(
                child: SvgPicture.asset(
                  isDark
                      ? 'assets/images/reflect-icon-dark.svg'
                      : 'assets/images/reflect-icon-light.svg',
                  height: 128,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      template.name,
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                  if (template.isSystem)
                    Chip(
                      label: const Text('System'),
                      labelStyle: Theme.of(ctx)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                              color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              if (template.descriptionEncrypted?.isNotEmpty ?? false) ...[
                const SizedBox(height: 8),
                Text(
                  template.descriptionEncrypted!,
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                ),
              ],
              const SizedBox(height: 16),
              // ── Metadata chips ───────────────────────────────────
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (template.defaultStakes != null)
                    _StakesBadge(stakes: template.defaultStakes!),
                  if (template.requiresApproval)
                    Chip(
                      avatar: const Icon(Icons.approval_outlined, size: 16),
                      label: const Text('Requires Approval'),
                      labelStyle:
                          Theme.of(ctx).textTheme.labelSmall,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              if (template.defaultCheckpointSchedule.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Checkpoint Schedule',
                  style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
                const SizedBox(height: 6),
                ...template.defaultCheckpointSchedule.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_outlined, size: 14),
                        const SizedBox(width: 6),
                        Text(c,
                            style: Theme.of(ctx).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ],
              if (template.suggestedStakeholderRoles.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Suggested Roles',
                  style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: template.suggestedStakeholderRoles
                      .map((r) => Chip(
                            label: Text(r),
                            labelStyle:
                                Theme.of(ctx).textTheme.labelSmall,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.push(Routes.decisionsCreate, extra: template);
                },
                child: const Text('Use this template'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(templatesProvider);
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (_isWorking)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New template',
              onPressed: _showCreateSheet,
            ),
        ],
      ),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load templates: $e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (templates) {
          final system =
              templates.where((t) => t.isSystem).toList();
          final mine =
              templates.where((t) => !t.isSystem).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ExpansionTile(
                title: Text('System Templates (${system.length})'),
                initiallyExpanded: false,
                children: [
                  if (system.isEmpty)
                    _EmptyHint('No system templates available.')
                  else
                    ...system.map(
                      (t) => _TemplateCard(
                        template: t,
                        onTap: () => _showDetail(t),
                        onLongPress: null,
                      ),
                    ),
                ],
              ),
              ExpansionTile(
                title: Text('My Templates (${mine.length})'),
                initiallyExpanded: false,
                children: [
                  if (mine.isEmpty)
                    _EmptyHint(
                        'No custom templates yet. Tap + to create one.'),
                  ...mine.map(
                    (t) => _TemplateCard(
                      template: t,
                      onTap: () => _showDetail(t),
                      onLongPress: () => _confirmDelete(t),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}


// ── Empty hint ──────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
      ),
    );
  }
}

// ── Template card ───────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.onTap,
    required this.onLongPress,
  });

  final DecisionTemplate template;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      template.name,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  if (template.defaultStakes != null)
                    _StakesBadge(stakes: template.defaultStakes!),
                ],
              ),
              if (template.descriptionEncrypted?.isNotEmpty ?? false) ...[
                const SizedBox(height: 4),
                Text(
                  template.descriptionEncrypted!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (template.requiresApproval)
                    _SmallChip(
                      icon: Icons.approval_outlined,
                      label: 'Approval',
                    ),
                  if (template.defaultCheckpointSchedule.isNotEmpty)
                    _SmallChip(
                      icon: Icons.schedule_outlined,
                      label:
                          '${template.defaultCheckpointSchedule.length} checkpoint${template.defaultCheckpointSchedule.length == 1 ? '' : 's'}',
                    ),
                  if (template.isSystem)
                    _SmallChip(
                      icon: Icons.verified_outlined,
                      label: 'System',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stakes badge ────────────────────────────────────────────────────────────

class _StakesBadge extends StatelessWidget {
  const _StakesBadge({required this.stakes});
  final String stakes;

  Color _bg(String s) => switch (s.toLowerCase()) {
        'critical' => AppColors.destructive.withValues(alpha: 0.15),
        'high' => AppColors.warning.withValues(alpha: 0.15),
        'medium' => AppColors.accentPrimary.withValues(alpha: 0.15),
        _ => AppColors.textMuted.withValues(alpha: 0.15),
      };

  Color _fg(String s) => switch (s.toLowerCase()) {
        'critical' => AppColors.destructive,
        'high' => AppColors.warning,
        'medium' => AppColors.accentPrimary,
        _ => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _bg(stakes),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        stakes,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _fg(stakes),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ── Small chip ──────────────────────────────────────────────────────────────

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }
}

// ── Shared template picker (used from CreateDecisionScreen) ─────────────────

/// Shows a bottom sheet with a searchable list of all templates.
/// Returns the selected [DecisionTemplate] or null if dismissed.
Future<DecisionTemplate?> showTemplatePicker(
    BuildContext context, WidgetRef ref) async {
  final templates = await ref.read(templatesProvider.future);

  if (!context.mounted) return null;

  return showModalBottomSheet<DecisionTemplate>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final system = templates.where((t) => t.isSystem).toList();
      final mine = templates.where((t) => !t.isSystem).toList();

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            Center(
              child: SvgPicture.asset(
                isDark
                    ? 'assets/images/reflect-icon-dark.svg'
                    : 'assets/images/reflect-icon-light.svg',
                height: 128,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a Template',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Pre-fills your decision form with defaults.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 16),
            if (templates.isEmpty)
              Center(
                child: Text(
                  'No templates available.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                ),
              ),
            if (system.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  'System Templates',
                  style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                ),
              ),
              ...system.map((t) => _PickerTile(
                    template: t,
                    onTap: () => Navigator.of(ctx).pop(t),
                  )),
              const SizedBox(height: 12),
            ],
            if (mine.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  'My Templates',
                  style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                ),
              ),
              ...mine.map((t) => _PickerTile(
                    template: t,
                    onTap: () => Navigator.of(ctx).pop(t),
                  )),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    },
  );
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.template, required this.onTap});
  final DecisionTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(template.name),
      subtitle: template.defaultStakes != null
          ? Text(template.defaultStakes!)
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
