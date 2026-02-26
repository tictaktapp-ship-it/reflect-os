import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/features/evidence/data/evidence_repository.dart';
import 'package:reflect_os/features/evidence/data/models/evidence_item.dart';

final evidenceRepositoryProvider = Provider<EvidenceRepository>(
  (ref) => const EvidenceRepository(),
);

final evidenceProvider =
    FutureProvider.family<List<EvidenceItem>, String>((ref, decisionId) {
  return ref
      .read(evidenceRepositoryProvider)
      .getEvidenceForDecision(decisionId);
});
