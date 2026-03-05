import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/features/sharing/data/models/share_link.dart';
import 'package:reflect_os/features/sharing/providers/sharing_provider.dart';

class ShareLinksScreen extends ConsumerStatefulWidget {
  const ShareLinksScreen({required this.decisionId, super.key});

  final String decisionId;

  @override
  ConsumerState<ShareLinksScreen> createState() => _ShareLinksScreenState();
}

class _ShareLinksScreenState extends ConsumerState<ShareLinksScreen> {
  String _buildShareUrl(String token) {
    final uri = Uri.base;
    final port = (uri.port != 0 && uri.port != 80 && uri.port != 443)
        ? ':${uri.port}'
        : '';
    return '${uri.scheme}://${uri.host}$port/#/share/$token';
  }

  Future<void> _copyUrl(String token) async {
    await Clipboard.setData(ClipboardData(text: _buildShareUrl(token)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied')),
      );
    }
  }

  Future<void> _revokeLink(ShareLink link) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Revoke Share Link'),
        content: const Text(
          'This link will immediately stop working. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.destructive),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(sharingRepositoryProvider).revokeShareLink(link.id);
      ref.invalidate(shareLinksProvider(widget.decisionId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to revoke link: $e'),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
  }

  Future<void> _showCreateSheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create Share Link',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how long the link should be active:',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('7 days'),
                onTap: () => Navigator.of(ctx).pop('7'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('30 days'),
                onTap: () => Navigator.of(ctx).pop('30'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.all_inclusive),
                title: const Text('No expiry'),
                onTap: () => Navigator.of(ctx).pop('none'),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == null || !mounted) return;

    DateTime? expiresAt;
    if (choice == '7') {
      expiresAt = DateTime.now().toUtc().add(const Duration(days: 7));
    } else if (choice == '30') {
      expiresAt = DateTime.now().toUtc().add(const Duration(days: 30));
    }

    try {
      final token = await ref
          .read(sharingRepositoryProvider)
          .createShareLink(widget.decisionId, expiresAt: expiresAt);
      ref.invalidate(shareLinksProvider(widget.decisionId));
      if (mounted) _showLinkCreatedDialog(token);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create link: $e'),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
  }

  void _showLinkCreatedDialog(String token) {
    final url = _buildShareUrl(token);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share Link Created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Copy and share this link:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                url,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied')),
                );
              }
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final linksAsync = ref.watch(shareLinksProvider(widget.decisionId));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SvgPicture.asset(
              Theme.of(context).brightness == Brightness.dark
                  ? 'assets/images/reflect-icon-dark.svg'
                  : 'assets/images/reflect-icon-light.svg',
              height: 160,
            ),
            const SizedBox(width: 8),
            const Text('Share Links'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create share link',
            onPressed: _showCreateSheet,
          ),
        ],
      ),
      body: linksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (links) => links.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.link_off,
                        size: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No share links yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to create a shareable link.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: links.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _ShareLinkCard(
                  link: links[i],
                  onCopy: () => _copyUrl(links[i].tokenHash),
                  onRevoke: () => _revokeLink(links[i]),
                ),
              ),
      ),
    );
  }
}

class _ShareLinkCard extends StatelessWidget {
  const _ShareLinkCard({
    required this.link,
    required this.onCopy,
    required this.onRevoke,
  });

  final ShareLink link;
  final VoidCallback onCopy;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    final isActive = link.isActive;

    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.destructive.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Revoked',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isActive
                              ? AppColors.success
                              : AppColors.destructive,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: 'Copy link',
                  onPressed: onCopy,
                ),
                if (isActive)
                  IconButton(
                    icon: const Icon(Icons.block, size: 20),
                    tooltip: 'Revoke',
                    color: AppColors.destructive,
                    onPressed: onRevoke,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Created ${fmt.format(link.createdAt.toLocal())}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              link.expiresAt != null
                  ? 'Expires ${fmt.format(link.expiresAt!.toLocal())}'
                  : 'No expiry',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
