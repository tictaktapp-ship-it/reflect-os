import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/features/coaching/data/coaching_repository.dart';
import 'package:reflect_os/features/coaching/data/models/coach_client_relationship.dart';
import 'package:reflect_os/features/coaching/data/models/coach_note.dart';
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

final coachNotesForDecisionProvider =
    FutureProvider.family<List<CoachNote>, String>((ref, decisionId) {
  return ref
      .read(coachingRepositoryProvider)
      .getNotesForDecision(decisionId);
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
