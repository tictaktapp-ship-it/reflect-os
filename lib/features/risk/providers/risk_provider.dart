import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/features/risk/data/models/risk_assessment.dart';
import 'package:reflect_os/features/risk/data/risk_repository.dart';

final riskRepositoryProvider = Provider<RiskRepository>(
  (ref) => const RiskRepository(),
);

final riskAssessmentProvider =
    FutureProvider.family<RiskAssessment?, String>((ref, decisionId) {
  return ref.read(riskRepositoryProvider).getLatestRiskAssessment(decisionId);
});
