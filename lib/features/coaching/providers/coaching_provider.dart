import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/features/coaching/data/coaching_repository.dart';
import 'package:reflect_os/features/coaching/data/models/coach_client_relationship.dart';
import 'package:reflect_os/features/coaching/data/models/coach_note.dart';
import 'package:reflect_os/features/coaching/data/models/coaching_action_item.dart';
import 'package:reflect_os/features/coaching/data/models/coaching_session.dart';
import 'package:reflect_os/features/coaching/data/models/coaching_session_note.dart';

final coachingRepositoryProvider = Provider<CoachingRepository>(
  (_) => const CoachingRepository(),
);

final myClientsProvider =
    FutureProvider<List<CoachClientRelationship>>((ref) {
  return ref.read(coachingRepositoryProvider).getMyClients();
});

final myCoachesProvider =
    FutureProvider<List<CoachClientRelationship>>((ref) {
  return ref.read(coachingRepositoryProvider).getMyCoaches();
});

// All clients including pending
final myClientsAllProvider =
    FutureProvider<List<CoachClientRelationship>>((ref) {
  return ref.read(coachingRepositoryProvider).getMyClientsAll();
});

// All coaches including pending
final myCoachesAllProvider =
    FutureProvider<List<CoachClientRelationship>>((ref) {
  return ref.read(coachingRepositoryProvider).getMyCoachesAll();
});

final coachNotesForDecisionProvider =
    FutureProvider.family<List<CoachNote>, String>((ref, decisionId) {
  return ref
      .read(coachingRepositoryProvider)
      .getNotesForDecision(decisionId);
});

// Coach notes for a client (all decisions)
final coachNotesForClientProvider =
    FutureProvider.family<List<CoachNote>, String>((ref, clientUserId) {
  return ref.read(coachingRepositoryProvider).getNotesForClient(clientUserId);
});

// Confidence adjustment sum for a decision
final coachConfidenceAdjustmentProvider =
    FutureProvider.family<int, String>((ref, decisionId) {
  return ref
      .read(coachingRepositoryProvider)
      .getConfidenceAdjustmentSum(decisionId);
});

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

// Action items for a client (coach view)
final actionItemsForClientProvider =
    FutureProvider.family<List<CoachingActionItem>, String>(
        (ref, clientUserId) {
  return ref.read(coachingRepositoryProvider).getActionItems(clientUserId);
});

// My action items (client view)
final myActionItemsProvider = FutureProvider<List<CoachingActionItem>>((ref) {
  return ref.read(coachingRepositoryProvider).getMyActionItems();
});
