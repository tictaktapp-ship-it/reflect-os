import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/features/settings/data/models/vertical_config.dart';
import 'package:reflect_os/features/settings/providers/vertical_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VerticalSettingsScreen extends ConsumerStatefulWidget {
  const VerticalSettingsScreen({super.key});

  @override
  ConsumerState<VerticalSettingsScreen> createState() =>
      _VerticalSettingsScreenState();
}

class _VerticalSettingsScreenState
    extends ConsumerState<VerticalSettingsScreen> {
  String? _workspaceId;
  String _selectedName = 'general';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final workspaceId = await ref.read(currentWorkspaceProvider.future);
    if (!mounted) return;
    _workspaceId = workspaceId;

    if (workspaceId != null) {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('vertical_$workspaceId') ?? 'general';
      if (!mounted) return;
      setState(() {
        _selectedName = name;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _applySelection() async {
    if (_workspaceId == null) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(selectedVerticalNotifierProvider.notifier)
          .setVertical(_selectedName, _workspaceId!);
      ref.invalidate(currentVerticalProvider);
      if (mounted) {
        final verticals = ref.read(verticalsProvider).valueOrNull ?? [];
        final chosen = verticals
            .where((v) => v.verticalName == _selectedName)
            .firstOrNull;
        final displayName = chosen?.displayName ?? _selectedName;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vertical updated to $displayName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final verticalsAsync = ref.watch(verticalsProvider);

    return verticalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to load verticals: $e'),
        ),
      ),
      data: (verticals) => Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Explanation ────────────────────────────────────
                Card(
                  color: Theme.of(context).colorScheme.surface,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Choose the vertical that best matches your '
                            'organisation. This customises suggested tags, '
                            'categories, and checkpoint schedules.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Vertical cards ─────────────────────────────────
                ...verticals.map(
                  (v) => _VerticalCard(
                    vertical: v,
                    isSelected: v.verticalName == _selectedName,
                    onTap: () =>
                        setState(() => _selectedName = v.verticalName),
                  ),
                ),

                const SizedBox(height: 80), // room for bottom button
              ],
            ),
          ),

          // ── Apply button ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _applySelection,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Apply'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Vertical card ─────────────────────────────────────────────────────────────

class _VerticalCard extends StatelessWidget {
  const _VerticalCard({
    required this.vertical,
    required this.isSelected,
    required this.onTap,
  });

  final VerticalConfig vertical;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.teal
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.12),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Radio indicator
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 12),
                child: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected ? Colors.teal : AppColors.textMuted,
                  size: 20,
                ),
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      vertical.displayName,
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: isSelected ? Colors.teal : null,
                                fontWeight: FontWeight.w600,
                              ),
                    ),

                    // Description
                    if (vertical.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        vertical.description,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                      ),
                    ],

                    // Suggested categories
                    if (vertical.suggestedCategories.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: vertical.suggestedCategories
                            .map(
                              (cat) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.teal.withValues(alpha: 0.12)
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  cat,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: isSelected
                                            ? Colors.teal
                                            : AppColors.textSecondary,
                                      ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],

                    // Tags count
                    if (vertical.suggestedTags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${vertical.suggestedTags.length} suggested tag${vertical.suggestedTags.length == 1 ? '' : 's'}',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.textMuted,
                                ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
