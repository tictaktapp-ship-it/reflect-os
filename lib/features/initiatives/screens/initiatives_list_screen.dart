import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/features/initiatives/data/models/initiative.dart';
import 'package:reflect_os/features/initiatives/providers/initiatives_provider.dart';

class InitiativesListScreen extends ConsumerWidget {
  const InitiativesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initiativesAsync = ref.watch(initiativesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Initiatives')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(Routes.initiativesCreate),
        child: const Icon(Icons.add),
      ),
      body: initiativesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load: $e', textAlign: TextAlign.center),
          ),
        ),
        data: (initiatives) {
          if (initiatives.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No initiatives yet.\nTap + to create one.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: initiatives.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _InitiativeTile(initiative: initiatives[index]),
          );
        },
      ),
    );
  }
}

class _InitiativeTile extends StatelessWidget {
  const _InitiativeTile({required this.initiative});

  final Initiative initiative;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.backgroundSurface,
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => context.push(
          '/initiatives/detail/${initiative.id}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                initiative.name,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (initiative.descriptionEncrypted != null &&
                  initiative.descriptionEncrypted!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  initiative.descriptionEncrypted!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
