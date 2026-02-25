import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/features/initiatives/data/initiatives_repository.dart';
import 'package:reflect_os/features/initiatives/data/models/initiative.dart';

final initiativesRepositoryProvider = Provider<InitiativesRepository>(
  (ref) => const InitiativesRepository(),
);

final initiativesProvider = FutureProvider<List<Initiative>>((ref) {
  return ref.read(initiativesRepositoryProvider).getInitiatives();
});

final initiativesForDecisionProvider =
    FutureProvider.family<List<Initiative>, String>((ref, decisionId) {
  return ref
      .read(initiativesRepositoryProvider)
      .getInitiativesForDecision(decisionId);
});
