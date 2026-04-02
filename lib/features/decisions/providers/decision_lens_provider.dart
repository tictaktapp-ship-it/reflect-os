import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/features/decisions/data/decision_lens_repository.dart';
import 'package:reflect_os/features/decisions/data/models/decision_lens_data.dart';

final decisionLensRepositoryProvider = Provider<DecisionLensRepository>(
  (ref) => const DecisionLensRepository(),
);

/// Fetches all lens data via separate independent queries — no JOINs.
///
/// Each table (outcome_updates, confidence_triggers, risk_assessments,
/// evidence_items, decision_stakeholders) is queried independently so that
/// a decision with many outcomes and triggers does not produce a Cartesian
/// product row explosion.
final decisionLensProvider =
    FutureProvider.family<DecisionLensData, String>((ref, decisionId) {
  return ref
      .read(decisionLensRepositoryProvider)
      .fetchAndCompute(decisionId);
});
