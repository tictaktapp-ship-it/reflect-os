import 'package:flutter/foundation.dart';

@immutable
class RiskAssessment {
  const RiskAssessment({
    required this.id,
    required this.decisionId,
    required this.provider,
    required this.model,
    required this.status,
    required this.outputJsonb,
    required this.createdAt,
    this.methodology,
    this.manualRisksJsonb,
    this.overallRiskLevelColumn,
    this.confidenceImpact = 0,
    this.approvedAt,
    this.approvedByUserId,
  });

  final String id;
  final String decisionId;
  final String provider;
  final String model;
  final String status;

  /// Raw output blob from the assess-risk Edge Function (AI path).
  final Map<String, dynamic> outputJsonb;

  final DateTime createdAt;

  // ── Structured columns (added in migration) ───────────────────────────────

  /// 'ai' | 'custom'
  final String? methodology;

  /// Risks entered manually (custom path).
  final Map<String, dynamic>? manualRisksJsonb;

  /// Top-level DB column; preferred over outputJsonb fallback.
  final String? overallRiskLevelColumn;

  /// Confidence adjustment applied at approval: −3…0.
  final int confidenceImpact;

  final DateTime? approvedAt;
  final String? approvedByUserId;

  // ── Computed accessors ────────────────────────────────────────────────────

  bool get isApproved => approvedAt != null;

  bool get isManual => methodology == 'custom';

  /// Prefers top-level column, falls back to outputJsonb for legacy rows.
  String? get overallRiskLevel =>
      overallRiskLevelColumn ?? outputJsonb['overall_risk_level'] as String?;

  /// Risks list: manual path → manualRisksJsonb, AI path → outputJsonb.
  List<Map<String, dynamic>> get risks {
    final source = isManual ? manualRisksJsonb : outputJsonb;
    final r = source?['risks'];
    if (r is! List) return [];
    return r.whereType<Map<String, dynamic>>().toList();
  }

  /// Legacy AI confidence field (0.0–1.0).
  double? get confidence {
    final v = outputJsonb['confidence'];
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return null;
  }

  String? get summary => outputJsonb['summary'] as String?;

  factory RiskAssessment.fromJson(Map<String, dynamic> json) {
    return RiskAssessment(
      id: json['id'] as String,
      decisionId: json['decision_id'] as String,
      provider: json['provider'] as String? ?? '',
      model: json['model'] as String? ?? '',
      status: json['status'] as String? ?? '',
      outputJsonb: (json['output_jsonb'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      methodology: json['methodology'] as String?,
      manualRisksJsonb: json['manual_risks_jsonb'] as Map<String, dynamic>?,
      overallRiskLevelColumn: json['overall_risk_level'] as String?,
      confidenceImpact: (json['confidence_impact'] as num?)?.toInt() ?? 0,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      approvedByUserId: json['approved_by_user_id'] as String?,
    );
  }
}
