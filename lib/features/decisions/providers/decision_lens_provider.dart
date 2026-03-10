import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/features/decisions/data/decision_lens_repository.dart';
import 'package:reflect_os/features/decisions/data/models/decision_lens_data.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';
import 'package:reflect_os/features/evidence/providers/evidence_provider.dart';
import 'package:reflect_os/features/outcomes/providers/outcomes_provider.dart';
import 'package:reflect_os/features/risk/providers/risk_provider.dart';

final decisionLensRepositoryProvider = Provider<DecisionLensRepository>(
  (ref) => const DecisionLensRepository(),
);

final decisionLensProvider =
    FutureProvider.family<DecisionLensData, String>((ref, decisionId) async {
  final decision =
      await ref.watch(decisionDetailProvider(decisionId).future);
  if (decision == null) throw Exception('Decision not found');

  final stakeholders =
      await ref.watch(stakeholdersProvider(decisionId).future);
  final riskAssessment =
      await ref.watch(riskAssessmentProvider(decisionId).future);
  final evidence =
      await ref.watch(evidenceProvider(decisionId).future);
  final outcomes =
      await ref.watch(outcomesProvider(decisionId).future);

  return ref.read(decisionLensRepositoryProvider).compute(
        decision: decision,
        stakeholders: stakeholders,
        riskAssessment: riskAssessment,
        evidence: evidence,
        outcomes: outcomes,
      );
});
