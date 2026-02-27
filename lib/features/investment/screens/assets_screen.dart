import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/features/investment/data/models/asset.dart';
import 'package:reflect_os/features/investment/providers/investment_provider.dart';

class AssetsScreen extends ConsumerWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(workspaceAssetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Portfolio')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAssetSheet(context, ref),
        tooltip: 'Add asset',
        child: const Icon(Icons.add),
      ),
      body: assetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load assets: $err',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (assets) {
          if (assets.isEmpty) {
            return const Center(
              child: Text('No assets yet. Tap + to add one.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: assets.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _AssetTile(asset: assets[i]),
          );
        },
      ),
    );
  }

  void _showAddAssetSheet(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final sectorCtrl = TextEditingController();
    final stageCtrl = TextEditingController();
    final geoCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          20,
          16,
          MediaQuery.of(ctx).viewInsets.bottom + 32,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSS) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add Asset',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name *'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sectorCtrl,
                decoration: const InputDecoration(labelText: 'Sector'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Stage (e.g. Series A, Growth)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: geoCtrl,
                decoration: const InputDecoration(labelText: 'Geography'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final workspaceId =
                      await ref.read(currentWorkspaceProvider.future);
                  if (workspaceId == null) return;
                  await ref.read(investmentRepositoryProvider).createAsset(
                        workspaceId: workspaceId,
                        name: name,
                        sector: sectorCtrl.text.trim().isEmpty
                            ? null
                            : sectorCtrl.text.trim(),
                        stage: stageCtrl.text.trim().isEmpty
                            ? null
                            : stageCtrl.text.trim(),
                        geography: geoCtrl.text.trim().isEmpty
                            ? null
                            : geoCtrl.text.trim(),
                      );
                  ref.invalidate(workspaceAssetsProvider);
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                },
                child: const Text('Add Asset'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Asset tile ─────────────────────────────────────────────────────────────────

class _AssetTile extends StatelessWidget {
  const _AssetTile({required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (asset.sector != null) asset.sector!,
      if (asset.stage != null) asset.stage!,
      if (asset.geography != null) asset.geography!,
    ];

    return Card(
      child: ListTile(
        leading: const Icon(Icons.business_outlined),
        title: Text(asset.name),
        subtitle: parts.isNotEmpty ? Text(parts.join(' · ')) : null,
      ),
    );
  }
}
