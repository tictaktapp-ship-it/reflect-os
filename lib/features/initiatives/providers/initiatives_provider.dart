import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/initiatives/data/initiatives_repository.dart';
import 'package:reflect_os/features/initiatives/data/models/initiative.dart';

final initiativesRepositoryProvider = Provider<InitiativesRepository>(
  (ref) => const InitiativesRepository(),
);

final initiativesProvider = FutureProvider<List<Initiative>>((ref) {
  return ref.read(initiativesRepositoryProvider).getInitiatives();
});

final initiativeDetailProvider =
    FutureProvider.family<Initiative?, String>((ref, id) {
  return ref.read(initiativesRepositoryProvider).getInitiativeById(id);
});

final decisionsForInitiativeProvider =
    FutureProvider.family<List<Decision>, String>((ref, initiativeId) {
  return ref
      .read(initiativesRepositoryProvider)
      .getDecisionsForInitiative(initiativeId);
});

final initiativesForDecisionProvider =
    FutureProvider.family<List<Initiative>, String>((ref, decisionId) {
  return ref
      .read(initiativesRepositoryProvider)
      .getInitiativesForDecision(decisionId);
});
