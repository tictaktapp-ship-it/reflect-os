import 'package:flutter/material.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import '../data/models/encryption_settings.dart';

/// Modal bottom sheet for confirming the switch to plaintext mode.
///
/// Requires a checkbox acknowledgement before the confirm button is enabled.
class PlaintextConfirmSheet extends StatefulWidget {
  const PlaintextConfirmSheet({super.key, required this.onConfirm});

  final Future<void> Function() onConfirm;

  @override
  State<PlaintextConfirmSheet> createState() => _PlaintextConfirmSheetState();
}

class _PlaintextConfirmSheetState extends State<PlaintextConfirmSheet> {
  bool _checked = false;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Disable encryption?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),

              // Warning block
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'New decisions created after this change will not be '
                        'encrypted. This does not affect existing decisions, '
                        'which remain encrypted. This setting can be reversed '
                        'at any time.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Checkbox acknowledgement
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _checked,
                    onChanged: _loading
                        ? null
                        : (v) => setState(() => _checked = v!),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: _loading
                          ? null
                          : () => setState(() => _checked = !_checked),
                      child: Text(
                        'I understand this applies to future decisions only, '
                        'and that existing decisions are not affected.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Confirm button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.destructive,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (_checked && !_loading) ? _onConfirm : null,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Confirm — disable encryption'),
                ),
              ),
              const SizedBox(height: 8),

              // Cancel
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed:
                      _loading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onConfirm() async {
    setState(() => _loading = true);
    try {
      await widget.onConfirm();
      if (mounted) Navigator.of(context).pop();
    } on EncryptionPermissionException catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update setting. Please try again.'),
          ),
        );
        setState(() => _loading = false);
      }
    }
  }
}
