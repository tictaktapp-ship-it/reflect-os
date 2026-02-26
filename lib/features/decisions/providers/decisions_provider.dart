import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/features/decisions/data/decisions_repository.dart';
import 'package:reflect_os/features/decisions/data/models/category.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/decisions/data/models/audit_event.dart';
import 'package:reflect_os/features/decisions/data/models/review_checkpoint.dart';

final decisionsRepositoryProvider = Provider<DecisionsRepository>(
  (ref) => const DecisionsRepository(),
);

final decisionsProvider = FutureProvider<List<Decision>>((ref) {
  return ref.read(decisionsRepositoryProvider).getDecisions();
});

final decisionDetailProvider =
    FutureProvider.family<Decision?, String>((ref, id) {
  return ref.read(decisionsRepositoryProvider).getDecisionById(id);
});

final searchProvider =
    FutureProvider.family<List<Decision>, String>((ref, query) {
  return ref.read(decisionsRepositoryProvider).searchDecisions(query);
});

final auditEventsProvider =
    FutureProvider.family<List<AuditEvent>, String>((ref, decisionId) async {
  final workspaceId = await ref.watch(currentWorkspaceProvider.future);
  if (workspaceId == null) return [];
  return ref
      .read(decisionsRepositoryProvider)
      .getAuditEventsForDecision(decisionId, workspaceId);
});

final checkpointsProvider =
    FutureProvider.family<List<ReviewCheckpoint>, String>((ref, decisionId) {
  return ref
      .read(decisionsRepositoryProvider)
      .getCheckpointsForDecision(decisionId);
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final workspaceId = await ref.watch(currentWorkspaceProvider.future);
  if (workspaceId == null) return [];
  return ref.read(decisionsRepositoryProvider).getCategories(workspaceId);
});
