import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import '../data/encryption_settings_repository.dart';
import '../data/models/encryption_settings.dart';
import '../providers/encryption_providers.dart';
import 'plaintext_confirm_sheet.dart';

/// Settings tile that shows the current workspace encryption mode and allows
/// the workspace owner to toggle it.
///
/// Non-owners see the tile in a disabled state with a tooltip explaining that
/// only owners can change this setting.
class EncryptionModeTile extends ConsumerWidget {
  const EncryptionModeTile({
    super.key,
    required this.workspaceId,
    required this.isOwner,
  });

  final String workspaceId;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync =
        ref.watch(encryptionSettingsProvider(workspaceId));

    return settingsAsync.when(
      loading: () => const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.lock_outline),
        title: Text('Encryption'),
        trailing: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (settings) {
        final mode =
            settings?.mode ?? EncryptionMode.encrypted;
        final isEncrypted = mode == EncryptionMode.encrypted;

        return Tooltip(
          message: isOwner
              ? ''
              : 'Only workspace owners can change this setting',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              isEncrypted ? Icons.lock_outline : Icons.lock_open_outlined,
              color: isEncrypted ? AppColors.success : AppColors.warning,
            ),
            title: const Text('Encryption'),
            subtitle: Text(
              isEncrypted ? 'Encrypted (recommended)' : 'Plaintext',
            ),
            trailing: Switch(
              value: isEncrypted,
              onChanged: isOwner
                  ? (value) => _onToggle(context, ref, value)
                  : null,
            ),
          ),
        );
      },
    );
  }

  Future<void> _onToggle(
      BuildContext context, WidgetRef ref, bool enableEncryption) async {
    if (enableEncryption) {
      // Switching back to encrypted — no confirmation needed
      await _setMode(context, ref, EncryptionMode.encrypted);
    } else {
      // Switching to plaintext — show confirmation sheet
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => PlaintextConfirmSheet(
          onConfirm: () => _setMode(context, ref, EncryptionMode.plaintext),
        ),
      );
    }
  }

  Future<void> _setMode(
      BuildContext context, WidgetRef ref, EncryptionMode mode) async {
    try {
      await const EncryptionSettingsRepository()
          .setMode(workspaceId: workspaceId, mode: mode);
      ref.invalidate(encryptionSettingsProvider(workspaceId));
    } on EncryptionPermissionException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Could not update encryption mode. Please try again.')),
        );
      }
    }
  }
}
