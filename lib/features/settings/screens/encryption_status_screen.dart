import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/services/encryption_service.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
      final keyOk = keyStatus['master_key_configured'] ?? false;

      // Check last 5 decisions.
      final decisions =
          ref.read(decisionsProvider).valueOrNull?.take(5).toList() ?? [];
      final newStatus = <String, Map<String, bool>>{};

      for (final d in decisions) {
        final status = await service.checkEncryptionStatus(
          workspaceId: workspaceId,
          fields: {'description': d.rawDescriptionEncrypted},
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
                          _keyConfigured == null
                              ? 'Encryption status unknown'
                              : _keyConfigured!
                                  ? 'Encryption active'
                                  : 'Encryption not active',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _keyConfigured == null
                              ? 'Tap Verify to check'
                              : _keyConfigured!
                                  ? 'Your decision content is encrypted at rest using AES-256-GCM'
                                  : 'Your decision content is currently stored as plaintext',
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

          // ── Contextual cards shown once status is known ──────────
          if (_keyConfigured == true) ...[
            // What is encrypted
            _InfoCard(
              icon: Icons.lock_outline,
              title: 'What is encrypted',
              children: [
                _BulletRow(label: 'Decision title'),
                _BulletRow(label: 'Description'),
                _BulletRow(label: 'Situational context'),
                _BulletRow(label: 'Projected outcome'),
                const SizedBox(height: 8),
                Text(
                  'Metadata such as category, stakes, deadline, and tags are not encrypted as they are used for filtering and analytics.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.55),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // What this means for you
            _InfoCard(
              icon: Icons.info_outline,
              title: 'What this means for you',
              children: [
                Text(
                  'Your decision content is encrypted before it is stored. Even if the database were accessed directly, your content would be unreadable without the encryption key.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Encryption and decryption happens automatically when you save or open a decision — you don\'t need to do anything.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          if (_keyConfigured == false) ...[
            // Action required warning card
            _ActionRequiredCard(),
            const SizedBox(height: 16),
          ],

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
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
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

// ── Shared info card ─────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.accentPrimary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ── Bullet row (used inside "What is encrypted") ─────────────────────────────

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline,
              size: 16, color: AppColors.success),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ── Action required card (encryption not configured) ─────────────────────────

class _ActionRequiredCard extends StatelessWidget {
  const _ActionRequiredCard();

  static final _mailUri = Uri.parse(
    'mailto:contact@reflect-os.com'
    '?subject=Encryption%20Setup'
    '&body=Please%20help%20configure%20encryption%20for%20my%20workspace.',
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: AppColors.warning.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 18, color: AppColors.warning),
                const SizedBox(width: 8),
                Text(
                  'Action required',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Encryption has not been configured for your workspace. Please contact us and we will get this resolved for you as quickly as possible.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => launchUrl(_mailUri),
              child: Text(
                'contact@reflect-os.com',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Once configured, new decisions will be encrypted automatically.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status row (per-decision list) ───────────────────────────────────────────

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
