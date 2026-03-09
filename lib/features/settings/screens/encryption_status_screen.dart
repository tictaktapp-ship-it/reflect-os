import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/services/encryption_service.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';

class EncryptionStatusScreen extends ConsumerStatefulWidget {
  const EncryptionStatusScreen({super.key});

  @override
  ConsumerState<EncryptionStatusScreen> createState() =>
      _EncryptionStatusScreenState();
}

class _EncryptionStatusScreenState
    extends ConsumerState<EncryptionStatusScreen> {
  bool _isVerifying = false;
  bool? _keyConfigured;
  // decisionId → { 'description': bool }
  Map<String, Map<String, bool>> _verifiedStatus = {};
  String? _error;

  Future<void> _verify() async {
    final workspaceId = ref.read(currentWorkspaceProvider).valueOrNull;
    if (workspaceId == null) return;

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      final service = ref.read(encryptionServiceProvider);

      // Check if master key is configured (empty fields probe).
      final keyStatus = await service.checkEncryptionStatus(
        workspaceId: workspaceId,
        fields: {},
      );
      final keyOk = keyStatus['key_configured'] ?? keyStatus.isNotEmpty;

      // Check last 5 decisions.
      final decisions =
          ref.read(decisionsProvider).valueOrNull?.take(5).toList() ?? [];
      final newStatus = <String, Map<String, bool>>{};

      for (final d in decisions) {
        final status = await service.checkEncryptionStatus(
          workspaceId: workspaceId,
          fields: {'description': d.descriptionEncrypted},
        );
        newStatus[d.id] = status;
      }

      if (mounted) {
        setState(() {
          _keyConfigured = keyOk;
          _verifiedStatus = newStatus;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Verification failed: $e');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decisions =
        ref.watch(decisionsProvider).valueOrNull?.take(5).toList() ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Encryption Status')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header ───────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.shield, size: 48, color: AppColors.accentPrimary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Encryption Status',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Verify that your decision content is encrypted at rest.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Master key status ────────────────────────────────────
          Card(
            color: theme.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _keyConfigured == null
                        ? Icons.help_outline
                        : _keyConfigured!
                            ? Icons.check_circle
                            : Icons.cancel,
                    color: _keyConfigured == null
                        ? null
                        : _keyConfigured!
                            ? AppColors.success
                            : AppColors.destructive,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Master key configured',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _keyConfigured == null
                              ? 'Tap Verify to check'
                              : _keyConfigured!
                                  ? 'AES-256-GCM key is active'
                                  : 'Key not found — contact support',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Per-decision status ──────────────────────────────────
          Text(
            'Recent decisions',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          if (decisions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No decisions yet.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),

          ...decisions.map((d) {
            final status = _verifiedStatus[d.id];
            final descOk = status?['description'];

            return Card(
              color: theme.colorScheme.surface,
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.title,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    _StatusRow(
                      label: 'Description',
                      isEncrypted: descOk,
                    ),
                  ],
                ),
              ),
            );
          }),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],

          const SizedBox(height: 24),

          // ── Verify button ────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: _isVerifying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.verified_user),
              label: Text(_isVerifying ? 'Verifying…' : 'Verify'),
              onPressed: _isVerifying ? null : _verify,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.isEncrypted});

  final String label;
  final bool? isEncrypted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          isEncrypted == null
              ? Icons.help_outline
              : isEncrypted!
                  ? Icons.check_circle_outline
                  : Icons.cancel_outlined,
          size: 14,
          color: isEncrypted == null
              ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
              : isEncrypted!
                  ? AppColors.success
                  : AppColors.warning,
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ${isEncrypted == null ? 'unknown' : isEncrypted! ? 'encrypted' : 'plaintext'}',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
