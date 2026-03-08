import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/features/demographic_packs/providers/demographic_packs_providers.dart';
import 'package:reflect_os/features/settings/providers/vertical_provider.dart';
import 'package:reflect_os/features/templates/providers/templates_provider.dart';
import 'package:reflect_os/features/workspace/providers/workspace_providers.dart';

class WorkspaceWizardScreen extends ConsumerStatefulWidget {
  const WorkspaceWizardScreen({super.key});

  @override
  ConsumerState<WorkspaceWizardScreen> createState() =>
      _WorkspaceWizardScreenState();
}

class _WorkspaceWizardScreenState
    extends ConsumerState<WorkspaceWizardScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;
  bool _isSaving = false;

  // Step 1 — name
  late final TextEditingController _nameCtrl;
  String? _savedWorkspaceName;

  // Step 2 — vertical
  String? _selectedVerticalId;
  String? _selectedVerticalName;

  // Step 3 — templates
  final _selectedTemplateIds = <String>{};

  // Step 4 — demographic packs
  final _enabledPackIds = <String>{};

  // Step 5 — branding
  late final TextEditingController _brandingCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _brandingCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Pre-fill workspace name
      final name = await ref.read(workspaceNameProvider.future);
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = name ?? '';
        _brandingCtrl.text = name ?? '';
        _savedWorkspaceName = name;
      });
      // Pre-select current vertical
      final vertical = await ref.read(currentVerticalProvider.future);
      if (!mounted || vertical == null) return;
      setState(() {
        _selectedVerticalId = vertical.id;
        _selectedVerticalName = vertical.verticalName;
      });
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _brandingCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _prevPage() => _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

  Future<void> _onNext() async {
    if (_currentPage == 0) {
      final newName = _nameCtrl.text.trim();
      if (newName.isNotEmpty && newName != _savedWorkspaceName) {
        setState(() => _isSaving = true);
        try {
          final workspaceId =
              await ref.read(currentWorkspaceProvider.future);
          if (workspaceId != null) {
            await ref
                .read(workspaceRepositoryProvider)
                .renameWorkspace(workspaceId, newName);
            ref.invalidate(userWorkspacesProvider);
            ref.invalidate(workspaceNameProvider);
            setState(() {
              _savedWorkspaceName = newName;
              _brandingCtrl.text = newName;
            });
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to save name: $e')),
            );
          }
          return;
        } finally {
          if (mounted) setState(() => _isSaving = false);
        }
      }
    }
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _onFinish() async {
    setState(() => _isSaving = true);
    try {
      final workspaceId = await ref.read(currentWorkspaceProvider.future);
      if (workspaceId == null) {
        if (mounted) context.go(Routes.settings);
        return;
      }

      // 1. Save vertical
      if (_selectedVerticalName != null) {
        await ref
            .read(selectedVerticalNotifierProvider.notifier)
            .setVertical(_selectedVerticalName!, workspaceId);
        ref.invalidate(currentVerticalProvider);
      }

      // 2. Save default demographic pack (first enabled pack)
      if (_enabledPackIds.isNotEmpty) {
        await ref
            .read(demographicPacksRepositoryProvider)
            .setDefaultPack(
                workspaceId: workspaceId,
                packId: _enabledPackIds.first);
      }

      // 3. Save branding display name if changed
      final brandingName = _brandingCtrl.text.trim();
      if (brandingName.isNotEmpty && brandingName != _savedWorkspaceName) {
        await ref
            .read(workspaceRepositoryProvider)
            .renameWorkspace(workspaceId, brandingName);
        ref.invalidate(userWorkspacesProvider);
        ref.invalidate(workspaceNameProvider);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workspace set up successfully')),
        );
        context.go(Routes.settings);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Step pages ────────────────────────────────────────────────────────────

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What's your workspace called?",
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Workspace name'),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final verticalsAsync = ref.watch(verticalsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose your vertical',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        verticalsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Failed to load verticals: $e'),
          data: (verticals) => Column(
            children: verticals
                .map(
                  (v) => RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(v.displayName),
                    subtitle: v.description.isNotEmpty
                        ? Text(v.description)
                        : null,
                    value: v.id,
                    groupValue: _selectedVerticalId,
                    onChanged: (val) => setState(() {
                      _selectedVerticalId = val;
                      _selectedVerticalName = v.verticalName;
                    }),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    final templatesAsync = ref.watch(templatesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pick starter templates',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        templatesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Failed to load templates: $e'),
          data: (templates) {
            final system = templates.where((t) => t.isSystem).toList();
            if (system.isEmpty) {
              return Text(
                'No system templates available.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              );
            }
            return Column(
              children: system
                  .map(
                    (t) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.name),
                      value: _selectedTemplateIds.contains(t.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selectedTemplateIds.add(t.id);
                        } else {
                          _selectedTemplateIds.remove(t.id);
                        }
                      }),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStep4() {
    final packsAsync = ref.watch(demographicPacksProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enable demographic packs',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        packsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Failed to load packs: $e'),
          data: (packs) => Column(
            children: packs
                .map(
                  (p) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.displayName),
                    subtitle: p.description.isNotEmpty
                        ? Text(p.description)
                        : null,
                    value: _enabledPackIds.contains(p.id),
                    onChanged: (v) => setState(() {
                      if (v) {
                        _enabledPackIds.add(p.id);
                      } else {
                        _enabledPackIds.remove(p.id);
                      }
                    }),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStep5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Branding (optional)',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'You can update this any time in settings.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _brandingCtrl,
          decoration:
              const InputDecoration(labelText: 'Workspace display name'),
          textCapitalization: TextCapitalization.words,
        ),
      ],
    );
  }

  // ── Layout helpers ────────────────────────────────────────────────────────

  Widget _wrapPage(Widget content, {required Widget navRow}) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(child: content),
          ),
          const SizedBox(height: 16),
          navRow,
        ],
      ),
    );
  }

  Widget _buildStandardNavRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentPage > 0)
          TextButton(
            onPressed: _prevPage,
            child: const Text('Back'),
          )
        else
          const SizedBox(),
        Row(
          children: [
            TextButton(
              onPressed: () => context.go(Routes.settings),
              child: const Text('Skip'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _isSaving ? null : _onNext,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFinishNavRow() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _isSaving ? null : _onFinish,
        child: _isSaving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Finish'),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _currentPage > 0
            ? BackButton(onPressed: _prevPage)
            : CloseButton(onPressed: () => context.go(Routes.settings)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            5,
            (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == _currentPage
                    ? AppColors.accentPrimary
                    : Colors.grey.shade300,
              ),
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => context.go(Routes.settings),
            child: const Text('Skip all'),
          ),
        ],
      ),
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _currentPage = i),
        children: [
          _wrapPage(_buildStep1(), navRow: _buildStandardNavRow()),
          _wrapPage(_buildStep2(), navRow: _buildStandardNavRow()),
          _wrapPage(_buildStep3(), navRow: _buildStandardNavRow()),
          _wrapPage(_buildStep4(), navRow: _buildStandardNavRow()),
          _wrapPage(_buildStep5(), navRow: _buildFinishNavRow()),
        ],
      ),
    );
  }
}
