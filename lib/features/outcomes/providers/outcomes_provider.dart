import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/features/outcomes/data/models/outcome_update.dart';
import 'package:reflect_os/features/outcomes/data/outcomes_repository.dart';

final outcomesRepositoryProvider = Provider<OutcomesRepository>(
  (ref) => const OutcomesRepository(),
);

final outcomesProvider =
    FutureProvider.family<List<OutcomeUpdate>, String>((ref, decisionId) {
  return ref
      .read(outcomesRepositoryProvider)
      .getOutcomesForDecision(decisionId);
});
