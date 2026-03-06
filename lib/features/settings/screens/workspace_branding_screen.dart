import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/features/settings/providers/settings_provider.dart';

// ── Preset colour swatches ─────────────────────────────────────────────────────

class _Preset {
  const _Preset(this.label, this.hex);
  final String label;
  final String hex;
}

const _kPresets = [
  _Preset('Teal', '#00B4A6'),
  _Preset('Navy', '#1A1A2E'),
  _Preset('Purple', '#7C3AED'),
  _Preset('Blue', '#2563EB'),
  _Preset('Green', '#16A34A'),
  _Preset('Red', '#DC2626'),
];

Color _hexToColor(String hex) {
  final clean = hex.replaceAll('#', '');
  if (clean.length == 6) {
    return Color(int.parse('FF$clean', radix: 16));
  }
  return Colors.teal;
}

bool _isValidHex(String hex) {
  final clean = hex.replaceAll('#', '');
  return RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(clean);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class WorkspaceBrandingScreen extends ConsumerStatefulWidget {
  const WorkspaceBrandingScreen({super.key});

  @override
  ConsumerState<WorkspaceBrandingScreen> createState() =>
      _WorkspaceBrandingScreenState();
}

class _WorkspaceBrandingScreenState
    extends ConsumerState<WorkspaceBrandingScreen> {
  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _logoUrlController = TextEditingController();
  final _primaryCustomController = TextEditingController();
  final _secondaryCustomController = TextEditingController();

  String _primaryHex = '#00B4A6';
  String _secondaryHex = '#1A1A2E';
  bool _primaryCustom = false;
  bool _secondaryCustom = false;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final branding = ref.read(workspaceBrandingProvider).valueOrNull;
    _applyBranding(branding);
  }

  void _applyBranding(dynamic branding) {
    if (branding == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    _nameController.text = branding.companyName ?? '';
    _taglineController.text = branding.companyTagline ?? '';
    _logoUrlController.text = branding.logoFileUrl ?? '';

    final ph = branding.primaryColorHex as String?;
    if (ph != null) {
      final match =
          _kPresets.where((p) => p.hex.toUpperCase() == ph.toUpperCase());
      if (match.isNotEmpty) {
        _primaryHex = match.first.hex;
        _primaryCustom = false;
      } else {
        _primaryHex = ph;
        _primaryCustomController.text = ph.replaceAll('#', '');
        _primaryCustom = true;
      }
    }

    final sh = branding.secondaryColorHex as String?;
    if (sh != null) {
      final match =
          _kPresets.where((p) => p.hex.toUpperCase() == sh.toUpperCase());
      if (match.isNotEmpty) {
        _secondaryHex = match.first.hex;
        _secondaryCustom = false;
      } else {
        _secondaryHex = sh;
        _secondaryCustomController.text = sh.replaceAll('#', '');
        _secondaryCustom = true;
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _logoUrlController.dispose();
    _primaryCustomController.dispose();
    _secondaryCustomController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final workspaceId = await ref.read(currentWorkspaceProvider.future);
    if (!mounted) return;
    if (workspaceId == null) return;

    final primaryHex = _primaryCustom
        ? '#${_primaryCustomController.text.replaceAll('#', '')}'
        : _primaryHex;
    final secondaryHex = _secondaryCustom
        ? '#${_secondaryCustomController.text.replaceAll('#', '')}'
        : _secondaryHex;

    if (_primaryCustom && !_isValidHex(primaryHex)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid primary colour hex value')),
      );
      return;
    }
    if (_secondaryCustom && !_isValidHex(secondaryHex)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid secondary colour hex value')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final logoUrl = _logoUrlController.text.trim();
      await ref.read(settingsRepositoryProvider).upsertWorkspaceBranding(
            workspaceId: workspaceId,
            companyName: _nameController.text.trim(),
            tagline: _taglineController.text.trim(),
            primaryColorHex: primaryHex.toUpperCase(),
            secondaryColorHex: secondaryHex.toUpperCase(),
            logoFileUrl: logoUrl.isEmpty ? null : logoUrl,
          );
      ref.invalidate(workspaceBrandingProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Branding saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-apply when provider resolves after the first async load.
    ref.listen(workspaceBrandingProvider, (_, next) {
      if (_isLoading) _applyBranding(next.valueOrNull);
    });

    final primaryColor = _primaryCustom &&
            _isValidHex(_primaryCustomController.text)
        ? _hexToColor('#${_primaryCustomController.text.replaceAll('#', '')}')
        : _hexToColor(_primaryHex);
    final secondaryColor = _secondaryCustom &&
            _isValidHex(_secondaryCustomController.text)
        ? _hexToColor(
            '#${_secondaryCustomController.text.replaceAll('#', '')}')
        : _hexToColor(_secondaryHex);

    return Scaffold(
      appBar: AppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Note ──────────────────────────────────────────────
                _SectionCard(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your branding is applied to all exported PDFs '
                            'and shared decision briefs.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // ── Company info ───────────────────────────────────────
                _SectionCard(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Company name',
                        hintText: 'Acme Corp',
                      ),
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _taglineController,
                      decoration: const InputDecoration(
                        labelText: 'Company tagline',
                        hintText: 'Better decisions, faster',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),

                // ── Logo URL ───────────────────────────────────────────
                _SectionCard(
                  children: [
                    TextField(
                      controller: _logoUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Logo URL',
                        hintText: 'https://your-cdn.com/logo.png',
                        helperText:
                            'File upload available post-deployment when '
                            'storage is configured.',
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  ],
                ),

                // ── Primary colour ─────────────────────────────────────
                _SectionCard(
                  children: [
                    Text(
                      'Primary Colour',
                      style:
                          Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                    ),
                    const SizedBox(height: 10),
                    _ColorSwatchRow(
                      selectedHex: _primaryCustom ? null : _primaryHex,
                      showCustom: _primaryCustom,
                      customController: _primaryCustomController,
                      onPresetSelected: (hex) => setState(() {
                        _primaryHex = hex;
                        _primaryCustom = false;
                      }),
                      onCustomToggled: () => setState(() {
                        _primaryCustom = true;
                      }),
                      onCustomChanged: (_) => setState(() {}),
                    ),
                  ],
                ),

                // ── Secondary colour ───────────────────────────────────
                _SectionCard(
                  children: [
                    Text(
                      'Secondary Colour',
                      style:
                          Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                    ),
                    const SizedBox(height: 10),
                    _ColorSwatchRow(
                      selectedHex: _secondaryCustom ? null : _secondaryHex,
                      showCustom: _secondaryCustom,
                      customController: _secondaryCustomController,
                      onPresetSelected: (hex) => setState(() {
                        _secondaryHex = hex;
                        _secondaryCustom = false;
                      }),
                      onCustomToggled: () => setState(() {
                        _secondaryCustom = true;
                      }),
                      onCustomChanged: (_) => setState(() {}),
                    ),
                  ],
                ),

                // ── Live preview ───────────────────────────────────────
                _SectionCard(
                  children: [
                    Text(
                      'Preview',
                      style:
                          Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                    ),
                    const SizedBox(height: 12),
                    _BrandingPreview(
                      companyName: _nameController.text.trim(),
                      tagline: _taglineController.text.trim(),
                      primaryColor: primaryColor,
                      secondaryColor: secondaryColor,
                      logoUrl: _logoUrlController.text.trim(),
                    ),
                  ],
                ),

                // ── Save ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Branding'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Colour swatch row ──────────────────────────────────────────────────────────

class _ColorSwatchRow extends StatelessWidget {
  const _ColorSwatchRow({
    required this.selectedHex,
    required this.showCustom,
    required this.customController,
    required this.onPresetSelected,
    required this.onCustomToggled,
    required this.onCustomChanged,
  });

  final String? selectedHex;
  final bool showCustom;
  final TextEditingController customController;
  final ValueChanged<String> onPresetSelected;
  final VoidCallback onCustomToggled;
  final ValueChanged<String> onCustomChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            ..._kPresets.map((preset) {
              final isSelected = selectedHex?.toUpperCase() ==
                  preset.hex.toUpperCase();
              return GestureDetector(
                onTap: () => onPresetSelected(preset.hex),
                child: Tooltip(
                  message: preset.label,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _hexToColor(preset.hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _hexToColor(preset.hex)
                                    .withValues(alpha: 0.4),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check,
                            size: 16, color: Colors.white)
                        : null,
                  ),
                ),
              );
            }),

            // Custom swatch
            GestureDetector(
              onTap: onCustomToggled,
              child: Tooltip(
                message: 'Custom',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: showCustom
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.3),
                      width: showCustom ? 3 : 1,
                    ),
                    gradient: const SweepGradient(
                      colors: [
                        Colors.red,
                        Colors.yellow,
                        Colors.green,
                        Colors.cyan,
                        Colors.blue,
                        Colors.purple,
                        Colors.red,
                      ],
                    ),
                  ),
                  child: showCustom
                      ? const Icon(Icons.check,
                          size: 16, color: Colors.white)
                      : null,
                ),
              ),
            ),
          ],
        ),
        if (showCustom) ...[
          const SizedBox(height: 10),
          TextField(
            controller: customController,
            decoration: const InputDecoration(
              labelText: 'Hex value',
              hintText: '00B4A6',
              prefixText: '#',
              isDense: true,
            ),
            maxLength: 6,
            onChanged: onCustomChanged,
          ),
        ],
      ],
    );
  }
}

// ── Live branding preview ──────────────────────────────────────────────────────

class _BrandingPreview extends StatelessWidget {
  const _BrandingPreview({
    required this.companyName,
    required this.tagline,
    required this.primaryColor,
    required this.secondaryColor,
    required this.logoUrl,
  });

  final String companyName;
  final String tagline;
  final Color primaryColor;
  final Color secondaryColor;
  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bar
          Container(
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Logo placeholder / actual logo
                if (logoUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      logoUrl,
                      height: 32,
                      width: 32,
                      fit: BoxFit.contain,
                      errorBuilder: (imgCtx, err, st) => _LogoPlaceholder(
                        color: secondaryColor,
                      ),
                    ),
                  )
                else
                  _LogoPlaceholder(color: secondaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        companyName.isEmpty ? 'Company Name' : companyName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (tagline.isNotEmpty)
                        Text(
                          tagline,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Mock PDF content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Decision Brief',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                _MockLine(color: textColor, width: double.infinity),
                const SizedBox(height: 4),
                _MockLine(color: textColor, width: 220),
                const SizedBox(height: 4),
                _MockLine(color: textColor, width: 180),
                const SizedBox(height: 12),

                // Colour swatches row
                Row(
                  children: [
                    _SwatchChip(color: primaryColor, label: 'Primary'),
                    const SizedBox(width: 8),
                    _SwatchChip(color: secondaryColor, label: 'Secondary'),
                  ],
                ),
              ],
            ),
          ),

          // Footer stripe
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: secondaryColor,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoPlaceholder extends StatelessWidget {
  const _LogoPlaceholder({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(Icons.business_outlined, size: 18, color: color),
    );
  }
}

class _MockLine extends StatelessWidget {
  const _MockLine({required this.color, required this.width});
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      width: width,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _SwatchChip extends StatelessWidget {
  const _SwatchChip({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ── Section card ───────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}
