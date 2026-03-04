import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import '../data/demographic_packs_repository.dart';
import '../providers/demographic_packs_providers.dart';
import '../widgets/pack_card.dart';

/// Displays available demographic packs and lets an owner set the
/// workspace default.
class PacksScreen extends ConsumerStatefulWidget {
  const PacksScreen({super.key});

  @override
  ConsumerState<PacksScreen> createState() => _PacksScreenState();
}

class _PacksScreenState extends ConsumerState<PacksScreen> {
  String? _settingDefaultPackId;

  Future<void> _setDefault(String workspaceId, String packId) async {
    setState(() => _settingDefaultPackId = packId);
    try {
      await const DemographicPacksRepository().setDefaultPack(
        workspaceId: workspaceId,
        packId: packId,
      );
      ref.invalidate(defaultPackIdProvider(workspaceId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update default pack: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _settingDefaultPackId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final packsAsync = ref.watch(demographicPacksProvider);
    final workspaceId = ref.watch(currentWorkspaceProvider).valueOrNull;
    final defaultIdAsync = workspaceId != null
        ? ref.watch(defaultPackIdProvider(workspaceId))
        : const AsyncValue<String?>.data(null);
    final defaultPackId = defaultIdAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Demographic Packs')),
      body: packsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Could not load packs: $e'),
        ),
        data: (packs) {
          if (packs.isEmpty) {
            return const Center(
              child: Text('No demographic packs available.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: packs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final pack = packs[index];
              return PackCard(
                pack: pack,
                isDefault: pack.id == defaultPackId,
                settingDefault: _settingDefaultPackId == pack.id,
                onSetDefault: workspaceId != null
                    ? () => _setDefault(workspaceId, pack.id)
                    : () {},
              );
            },
          );
        },
      ),
    );
  }
}
