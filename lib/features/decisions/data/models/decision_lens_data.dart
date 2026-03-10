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

class DecisionLensData {
  const DecisionLensData({
    required this.confidenceScore,
    required this.healthScore,
    required this.influenceNodes,
    required this.scoreComponents,
  });

  /// Initial confidence 0–10.
  final double confidenceScore;

  /// Derived health score 0–100.
  final int healthScore;

  final List<InfluenceNode> influenceNodes;
  final List<ScoreComponent> scoreComponents;
}
