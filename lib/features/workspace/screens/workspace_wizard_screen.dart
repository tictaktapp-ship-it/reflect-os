import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/features/demographic_packs/providers/demographic_packs_providers.dart';
import 'package:reflect_os/features/settings/providers/vertical_provider.dart';
import 'package:reflect_os/features/templates/providers/templates_provider.dart';

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

  // Step 1 — name
  late final TextEditingController _nameCtrl;

  // Step 2 — vertical
  String? _selectedVerticalId;
  String? _selectedVerticalName;

  // Step 3 — templates
  final _selectedTemplateIds = <String>{};

  // Step 4 — demographic packs
  final _enabledPackIds = <String>{};

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Pre-fill workspace name
      final name = await ref.read(workspaceNameProvider.future);
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = name ?? '';
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
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _prevPage() => _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

  Future<void> _onFinish() async {
    try {
      final workspaceId = await ref.read(currentWorkspaceProvider.future);
      if (workspaceId == null) {
        if (mounted) context.go(Routes.home);
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

      if (mounted) {
        context.go(Routes.home);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setup failed: $e')),
        );
      }
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

  // ── Layout helpers ────────────────────────────────────────────────────────

  // Wraps step content in a scrollable page — nav row is NOT included here.
  Widget _buildPageContent(Widget content) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: content,
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
            4,
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
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                _buildPageContent(_buildStep1()),
                _buildPageContent(_buildStep2()),
                _buildPageContent(_buildStep3()),
                _buildPageContent(_buildStep4()),
              ],
            ),
          ),
          // ── Hardcoded nav row — guaranteed visible regardless of keyboard ──
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentPage > 0)
                  TextButton(
                    onPressed: () {
                      _pageCtrl.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      setState(() => _currentPage--);
                    },
                    child: const Text('Back'),
                  )
                else
                  const SizedBox.shrink(),
                ElevatedButton(
                  onPressed: () {
                    debugPrint('Next tapped on page $_currentPage');
                    if (_currentPage < 3) {
                      _pageCtrl.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      setState(() => _currentPage++);
                    } else {
                      _onFinish();
                    }
                  },
                  child: Text(_currentPage < 3 ? 'Next' : 'Finish'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
