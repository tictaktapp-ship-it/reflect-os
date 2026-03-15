import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/decisions/data/models/decision_stakeholder.dart';
import 'package:reflect_os/features/initiatives/data/initiatives_repository.dart';
import 'package:reflect_os/features/initiatives/data/models/initiative.dart';

final initiativesRepositoryProvider = Provider<InitiativesRepository>(
  (ref) => const InitiativesRepository(),
);

final initiativesProvider =
    FutureProvider.autoDispose<List<Initiative>>((ref) async {
  final workspaceId = await ref.watch(currentWorkspaceProvider.future);
  if (workspaceId == null) return [];
  return ref
      .read(initiativesRepositoryProvider)
      .getInitiatives(workspaceId: workspaceId);
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

final linkedDecisionIdsProvider =
    FutureProvider.family.autoDispose<List<String>, String>(
        (ref, initiativeId) {
  return ref
      .read(initiativesRepositoryProvider)
      .getLinkedDecisionIds(initiativeId);
});

final peopleForInitiativeProvider =
    FutureProvider.family<List<DecisionStakeholder>, String>(
        (ref, initiativeId) {
  return ref
      .read(initiativesRepositoryProvider)
      .getPeopleForInitiative(initiativeId);
});
