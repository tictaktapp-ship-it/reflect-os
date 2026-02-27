import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/features/sharing/data/models/share_link.dart';
import 'package:reflect_os/features/sharing/data/sharing_repository.dart';

final sharingRepositoryProvider = Provider<SharingRepository>(
  (ref) => const SharingRepository(),
);

final shareLinksProvider =
    FutureProvider.family<List<ShareLink>, String>((ref, decisionId) {
  return ref.read(sharingRepositoryProvider).getShareLinks(decisionId);
});
