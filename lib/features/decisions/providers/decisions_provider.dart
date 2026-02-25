import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/features/decisions/data/decisions_repository.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';

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
