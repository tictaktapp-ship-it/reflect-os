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
  });

  final String id;
  final String decisionId;
  final String provider;
  final String model;
  final String status;

  /// The raw output JSON blob from the assess-risk Edge Function.
  final Map<String, dynamic> outputJsonb;

  final DateTime createdAt;

  // ── Typed accessors into outputJsonb ──────────────────────────────────────

  String? get overallRiskLevel => outputJsonb['overall_risk_level'] as String?;

  double? get confidence {
    final v = outputJsonb['confidence'];
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return null;
  }

  List<Map<String, dynamic>> get risks {
    final r = outputJsonb['risks'];
    if (r is! List) return [];
    return r.whereType<Map<String, dynamic>>().toList();
  }

  String? get summary => outputJsonb['summary'] as String?;

  factory RiskAssessment.fromJson(Map<String, dynamic> json) {
    return RiskAssessment(
      id: json['id'] as String,
      decisionId: json['decision_id'] as String,
      provider: json['provider'] as String? ?? '',
      model: json['model'] as String? ?? '',
      status: json['status'] as String? ?? '',
      outputJsonb:
          (json['output_jsonb'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
