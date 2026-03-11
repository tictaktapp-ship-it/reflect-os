import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/features/decisions/data/decisions_repository.dart';
import 'package:reflect_os/features/decisions/data/models/approval_record.dart';
import 'package:reflect_os/features/decisions/data/models/category.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/decisions/data/models/audit_event.dart';
import 'package:reflect_os/features/decisions/data/models/comment.dart';
import 'package:reflect_os/features/decisions/data/models/comment_thread.dart';
import 'package:reflect_os/features/decisions/data/models/decision_relationship.dart';
import 'package:reflect_os/features/decisions/data/models/decision_stakeholder.dart';
import 'package:reflect_os/features/decisions/data/models/review_checkpoint.dart';

final decisionsRepositoryProvider = Provider<DecisionsRepository>(
  (ref) => const DecisionsRepository(),
);

final decisionsProvider =
    FutureProvider.autoDispose<List<Decision>>((ref) async {
  final workspaceId = await ref.watch(currentWorkspaceProvider.future);
  if (workspaceId == null) return [];
  return ref
      .read(decisionsRepositoryProvider)
      .getDecisions(workspaceId: workspaceId);
});

final decisionDetailProvider =
    FutureProvider.family<Decision?, String>((ref, id) {
  return ref.read(decisionsRepositoryProvider).getDecisionById(id);
});

/// Fetches and decrypts the projected_outcome_encrypted field for a single
/// decision. autoDispose ensures fresh data on every screen mount (e.g.
/// after tool injection navigates back to the detail screen).
final projectedOutcomeProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, decisionId) {
  return ref
      .read(decisionsRepositoryProvider)
      .getProjectedOutcome(decisionId);
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

final commentThreadProvider =
    FutureProvider.family<CommentThread?, String>((ref, decisionId) {
  return ref
      .read(decisionsRepositoryProvider)
      .getCommentThread(decisionId);
});

final commentsProvider =
    FutureProvider.family<List<Comment>, String>((ref, threadId) {
  return ref.read(decisionsRepositoryProvider).getComments(threadId);
});

final stakeholdersProvider =
    FutureProvider.family<List<DecisionStakeholder>, String>(
        (ref, decisionId) {
  return ref
      .read(decisionsRepositoryProvider)
      .getStakeholders(decisionId);
});

final checkpointsProvider =
    FutureProvider.family<List<ReviewCheckpoint>, String>((ref, decisionId) {
  return ref
      .read(decisionsRepositoryProvider)
      .getCheckpointsForDecision(decisionId);
});

/// All Scheduled checkpoints due within the next 7 days (workspace-scoped via RLS).
final upcomingCheckpointsProvider =
    FutureProvider<List<ReviewCheckpoint>>((ref) {
  return ref.read(decisionsRepositoryProvider).getUpcomingCheckpoints();
});

final decisionRelationshipsProvider =
    FutureProvider.family<List<DecisionRelationship>, String>(
        (ref, decisionId) {
  return ref
      .read(decisionsRepositoryProvider)
      .getRelationshipsForDecision(decisionId);
});

final approvalRecordsProvider =
    FutureProvider.family<List<ApprovalRecord>, String>((ref, decisionId) {
  return ref
      .read(decisionsRepositoryProvider)
      .getApprovalRecords(decisionId);
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final workspaceId = await ref.watch(currentWorkspaceProvider.future);
  if (workspaceId == null) return [];
  return ref.read(decisionsRepositoryProvider).getCategories(workspaceId);
});
