import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/demographic_packs_repository.dart';
import '../data/models/demographic_pack.dart';

final demographicPacksRepositoryProvider =
    Provider<DemographicPacksRepository>(
  (_) => const DemographicPacksRepository(),
);

final demographicPacksProvider =
    FutureProvider<List<DemographicPack>>((ref) {
  return ref.read(demographicPacksRepositoryProvider).getPacks();
});

final defaultPackIdProvider =
    FutureProvider.family<String?, String>((ref, workspaceId) {
  return ref
      .read(demographicPacksRepositoryProvider)
      .getDefaultPackId(workspaceId);
});
