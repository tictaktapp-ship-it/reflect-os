import 'package:flutter/foundation.dart';

// ── Trigger types ─────────────────────────────────────────────────────────────

enum TriggerType {
  firstReview,
  riskSignal,
  positiveMomentum,
  criticalLow,
  strongOutcome,
  overconfidence,
  underconfidence,
  reviewGap,
  manual;

  static TriggerType fromString(String s) {
    return TriggerType.values.firstWhere(
      (e) => e.name == _toCamel(s),
      orElse: () => TriggerType.manual,
    );
  }

  static String _toCamel(String snake) {
    final parts = snake.split('_');
    return parts[0] +
        parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
  }
}

@immutable
class ConfidenceTrigger {
  const ConfidenceTrigger({
    required this.id,
    required this.decisionId,
    required this.triggerType,
    required this.triggerDate,
    required this.title,
    this.description,
    required this.influenceStrength,
    this.confidenceDelta,
    required this.arcPosition,
  });

  final String id;
  final String decisionId;
  final TriggerType triggerType;
  final DateTime triggerDate;
  final String title;
  final String? description;

  /// 1–5
  final int influenceStrength;

  /// Nullable — e.g. +2.0, -1.5
  final double? confidenceDelta;

  /// 0.0–1.0 normalised position on the arc
  final double arcPosition;

  factory ConfidenceTrigger.fromJson(Map<String, dynamic> j) {
    return ConfidenceTrigger(
      id: j['id'] as String,
      decisionId: j['decision_id'] as String,
      triggerType: TriggerType.fromString(j['trigger_type'] as String),
      triggerDate: DateTime.parse(j['trigger_date'] as String),
      title: j['title'] as String,
      description: j['description'] as String?,
      influenceStrength: j['influence_strength'] as int? ?? 3,
      confidenceDelta: (j['confidence_delta'] as num?)?.toDouble(),
      arcPosition: (j['arc_position'] as num?)?.toDouble() ?? 0.5,
    );
  }
}

// ── Influence node ─────────────────────────────────────────────────────────────

class InfluenceNode {
  const InfluenceNode({
    required this.label,
    required this.type,
    this.subtitle,
  });

  final String label;

  /// 'stakeholder' | 'risk' | 'evidence' | 'outcome'
  final String type;
  final String? subtitle;
}

// ── Score component ────────────────────────────────────────────────────────────

class ScoreComponent {
  const ScoreComponent({
    required this.label,
    required this.value,
    required this.displayValue,
  });

  final String label;

  /// Normalised 0.0–1.0
  final double value;
  final String displayValue;
}

// ── Aggregate lens data ────────────────────────────────────────────────────────

class DecisionLensData {
  const DecisionLensData({
    required this.confidenceScore,
    required this.healthScore,
    required this.influenceNodes,
    required this.scoreComponents,
    required this.triggers,
  });

  /// Initial confidence 0–10.
  final double confidenceScore;

  /// Derived health score 0–100.
  final int healthScore;

  final List<InfluenceNode> influenceNodes;
  final List<ScoreComponent> scoreComponents;
  final List<ConfidenceTrigger> triggers;
}
