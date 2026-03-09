class CreateDecisionInput {
  const CreateDecisionInput({
    required this.workspaceId,
    required this.title,
    this.state = 'Draft',
    this.categoryId,
    this.stakes,
    this.initialConfidence,
    this.descriptionEncrypted,
    this.decisionDeadline,
    this.isContinuous = false,
    this.visibility = 'workspace',
    this.requiresApproval = false,
    this.projectedOutcome,
  });

  final String workspaceId;
  final String title;
  final String state;
  final String? categoryId;
  final String? stakes;
  final int? initialConfidence;
  final String? descriptionEncrypted;
  final DateTime? decisionDeadline;
  final bool isContinuous;
  final String visibility;
  final bool requiresApproval;
  final String? projectedOutcome;

  Map<String, dynamic> toJson() => {
        'workspace_id': workspaceId,
        'title': title,
        'state': state,
        if (categoryId != null && categoryId!.isNotEmpty) 'category_id': categoryId,
        if (stakes != null) 'stakes': stakes,
        if (initialConfidence != null) 'initial_confidence': initialConfidence,
        if (descriptionEncrypted != null)
          'description_encrypted': descriptionEncrypted,
        if (decisionDeadline != null)
          'decision_deadline': decisionDeadline!.toIso8601String(),
        'continuous': isContinuous,
        'visibility_mode': visibility,
        'requires_approval': requiresApproval,
        if (projectedOutcome != null) 'projected_outcome_encrypted': projectedOutcome,
      };
}
