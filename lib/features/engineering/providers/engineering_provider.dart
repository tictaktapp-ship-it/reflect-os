import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/features/engineering/data/engineering_repository.dart';
import 'package:reflect_os/features/engineering/data/models/engineering_artifact_link.dart';

final engineeringRepositoryProvider = Provider<EngineeringRepository>(
  (_) => const EngineeringRepository(),
);

final engineeringArtifactsProvider =
    FutureProvider.family<List<EngineeringArtifactLink>, String>(
        (ref, decisionId) {
  return ref
      .read(engineeringRepositoryProvider)
      .getArtifactsForDecision(decisionId);
});
