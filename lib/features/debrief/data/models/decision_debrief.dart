import 'package:flutter/foundation.dart';

@immutable
class DecisionDebrief {
  const DecisionDebrief({
    required this.id,
    required this.decisionId,
    required this.requestedByUserId,
    required this.provider,
    required this.model,
    required this.status,
    required this.outputJsonb,
    this.userFeedback,
    required this.createdAt,
  });

  final String id;
  final String decisionId;
  final String requestedByUserId;
  final String provider;
  final String model;
  final String status;
  final Map<String, dynamic> outputJsonb;
  final String? userFeedback;
  final DateTime createdAt;

  // ── Typed accessors into outputJsonb ──────────────────────────────────────

  String? get verdict => outputJsonb['verdict'] as String?;
  String? get qualityTrajectory =>
      outputJsonb['quality_trajectory'] as String?;
  String? get confidenceCalibration =>
      outputJsonb['confidence_calibration'] as String?;
  String? get summary => outputJsonb['summary'] as String?;

  List<String> get keyLessons => _stringList(outputJsonb['key_lessons']);
  List<String> get whatWorked => _stringList(outputJsonb['what_worked']);
  List<String> get whatToImprove => _stringList(outputJsonb['what_to_improve']);
  List<String> get patternFlags => _stringList(outputJsonb['pattern_flags']);

  static List<String> _stringList(dynamic value) {
    if (value is! List) return [];
    return value.whereType<String>().toList();
  }

  factory DecisionDebrief.fromJson(Map<String, dynamic> json) {
    return DecisionDebrief(
      id: json['id'] as String,
      decisionId: json['decision_id'] as String,
      requestedByUserId: json['requested_by_user_id'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      model: json['model'] as String? ?? '',
      status: json['status'] as String? ?? '',
      outputJsonb:
          (json['output_jsonb'] as Map<String, dynamic>?) ?? {},
      userFeedback: json['user_feedback'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
