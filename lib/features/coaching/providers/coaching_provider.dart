import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/features/coaching/data/coaching_repository.dart';
import 'package:reflect_os/features/coaching/data/models/coach_client_relationship.dart';
import 'package:reflect_os/features/coaching/data/models/coach_note.dart';
import 'package:reflect_os/features/coaching/data/models/coach_shared_decision.dart';
import 'package:reflect_os/features/coaching/data/models/coaching_action_item.dart';
import 'package:reflect_os/features/coaching/data/models/coaching_session.dart';
import 'package:reflect_os/features/coaching/data/models/coaching_session_note.dart';
import 'package:reflect_os/features/coaching/data/models/cross_client_dashboard.dart';

final coachingRepositoryProvider = Provider<CoachingRepository>(
  (_) => const CoachingRepository(),
);

// ── Relationship providers ─────────────────────────────────────────────────

final myClientsProvider =
    FutureProvider<List<CoachClientRelationship>>((ref) {
  return ref.read(coachingRepositoryProvider).getMyClients();
});

final myCoachesProvider =
    FutureProvider<List<CoachClientRelationship>>((ref) {
  return ref.read(coachingRepositoryProvider).getMyCoaches();
});

final myClientsAllProvider =
    FutureProvider<List<CoachClientRelationship>>((ref) {
  return ref.read(coachingRepositoryProvider).getMyClientsAll();
});

final myCoachesAllProvider =
    FutureProvider<List<CoachClientRelationship>>((ref) {
  return ref.read(coachingRepositoryProvider).getMyCoachesAll();
});

// ── Shared decision providers ──────────────────────────────────────────────

/// Coach view: decisions a specific client has shared with this coach.
final sharedDecisionsByClientProvider =
    FutureProvider.family<List<CoachSharedDecision>, String>(
        (ref, clientUserId) {
  return ref
      .read(coachingRepositoryProvider)
      .getSharedDecisionsForClient(clientUserId);
});

/// Client view: all decisions this user has shared with any coach.
final clientSharedDecisionsProvider =
    FutureProvider<List<CoachSharedDecision>>((ref) {
  return ref.read(coachingRepositoryProvider).getMySharedDecisions();
});

// ── Cross-client dashboard ─────────────────────────────────────────────────

final crossClientDashboardProvider =
    FutureProvider<CrossClientDashboard>((ref) {
  return ref.read(coachingRepositoryProvider).getCrossClientDashboard();
});

// ── Note providers ─────────────────────────────────────────────────────────

final coachNotesForDecisionProvider =
    FutureProvider.family<List<CoachNote>, String>((ref, decisionId) {
  return ref
      .read(coachingRepositoryProvider)
      .getNotesForDecision(decisionId);
});

final coachNotesForClientProvider =
    FutureProvider.family<List<CoachNote>, String>((ref, clientUserId) {
  return ref
      .read(coachingRepositoryProvider)
      .getNotesForClient(clientUserId);
});

/// Client view: notes shared with the current user by their coaches.
final notesSharedWithMeProvider =
    FutureProvider<List<CoachNote>>((ref) {
  return ref.read(coachingRepositoryProvider).getNotesSharedWithMe();
});

final coachConfidenceAdjustmentProvider =
    FutureProvider.family<int, String>((ref, decisionId) {
  return ref
      .read(coachingRepositoryProvider)
      .getConfidenceAdjustmentSum(decisionId);
});

// ── Session providers ──────────────────────────────────────────────────────

final coachingSessionsProvider =
    FutureProvider.family<List<CoachingSession>, String>(
  (ref, clientUserId) {
    return ref
        .read(coachingRepositoryProvider)
        .getSessions(clientUserId: clientUserId);
  },
);

final coachingSessionNotesProvider =
    FutureProvider.family<List<CoachingSessionNote>, String>(
  (ref, clientUserId) {
    return ref
        .read(coachingRepositoryProvider)
        .getSessionNotes(clientUserId);
  },
);

/// Client view: session notes where the current user is the client.
final mySessionNotesProvider =
    FutureProvider<List<CoachingSessionNote>>((ref) {
  return ref.read(coachingRepositoryProvider).getMySessionNotes();
});

// ── Action item providers ──────────────────────────────────────────────────

final actionItemsForClientProvider =
    FutureProvider.family<List<CoachingActionItem>, String>(
        (ref, clientUserId) {
  return ref
      .read(coachingRepositoryProvider)
      .getActionItems(clientUserId);
});

final myActionItemsProvider =
    FutureProvider<List<CoachingActionItem>>((ref) {
  return ref.read(coachingRepositoryProvider).getMyActionItems();
});
