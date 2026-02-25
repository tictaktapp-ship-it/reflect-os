class CreateDecisionInput {
  const CreateDecisionInput({
    required this.workspaceId,
    required this.title,
    this.state = 'draft',
    this.categoryId,
    this.stakes,
    this.initialConfidence,
    this.descriptionEncrypted,
    this.decisionDeadline,
    this.isContinuous = false,
    this.visibility = 'workspace',
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

  Map<String, dynamic> toJson() => {
        'workspace_id': workspaceId,
        'title': title,
        'state': state,
        if (categoryId != null) 'category_id': categoryId,
        if (stakes != null) 'stakes': stakes,
        if (initialConfidence != null) 'initial_confidence': initialConfidence,
        if (descriptionEncrypted != null)
          'description_encrypted': descriptionEncrypted,
        if (decisionDeadline != null)
          'decision_deadline': decisionDeadline!.toIso8601String(),
        'is_continuous': isContinuous,
        'visibility': visibility,
      };
}
