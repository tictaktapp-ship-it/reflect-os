import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/features/risk/data/models/risk_assessment.dart';
import 'package:reflect_os/features/risk/data/risk_repository.dart';

final riskRepositoryProvider = Provider<RiskRepository>(
  (ref) => const RiskRepository(),
);

final riskAssessmentProvider =
    FutureProvider.family.autoDispose<RiskAssessment?, String>((ref, decisionId) {
  return ref.read(riskRepositoryProvider).getLatestRiskAssessment(decisionId);
});

final approvedRiskAssessmentProvider =
    FutureProvider.family.autoDispose<RiskAssessment?, String>((ref, decisionId) {
  return ref.read(riskRepositoryProvider).getApprovedRiskAssessment(decisionId);
});

/// Sum of confidence_impact from all approved risk assessments for a decision.
final riskConfidenceAdjustmentProvider =
    FutureProvider.family.autoDispose<int, String>((ref, decisionId) {
  return ref
      .read(riskRepositoryProvider)
      .getRiskConfidenceAdjustment(decisionId);
});

/// Effective health state, overridden by approved risk level:
///   critical → 'overdue'
///   high     → at minimum 'needs_attention'
final effectiveHealthStateProvider = FutureProvider.family
    .autoDispose<String?, ({String decisionId, String? dbHealthState})>(
  (ref, args) async {
    final assessment = await ref
        .read(riskRepositoryProvider)
        .getApprovedRiskAssessment(args.decisionId);
    if (assessment == null) return args.dbHealthState;
    final level = assessment.overallRiskLevel?.toLowerCase();
    final db = args.dbHealthState;
    if (level == 'critical') return 'overdue';
    if (level == 'high') {
      if (db == null || db == 'on_track') return 'needs_attention';
    }
    return db;
  },
);
