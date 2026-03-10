import 'package:flutter/material.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/features/decisions/data/models/decision_lens_data.dart';

Color triggerColor(TriggerType type) {
  switch (type) {
    case TriggerType.firstReview:
      return AppColors.accentPrimary;
    case TriggerType.riskSignal:
    case TriggerType.criticalLow:
    case TriggerType.overconfidence:
      return const Color(0xFFC13333);
    case TriggerType.positiveMomentum:
    case TriggerType.strongOutcome:
      return const Color(0xFF1A8C5E);
    case TriggerType.underconfidence:
    case TriggerType.reviewGap:
      return const Color(0xFFB86A0F);
    case TriggerType.manual:
      return AppColors.textMuted;
  }
}

String triggerIcon(TriggerType type) {
  switch (type) {
    case TriggerType.firstReview:
      return '◆';
    case TriggerType.riskSignal:
      return '⚠';
    case TriggerType.criticalLow:
      return '!';
    case TriggerType.overconfidence:
    case TriggerType.underconfidence:
      return '◈';
    case TriggerType.positiveMomentum:
      return '↑';
    case TriggerType.strongOutcome:
      return '★';
    case TriggerType.reviewGap:
      return '⏱';
    case TriggerType.manual:
      return '✎';
  }
}

String triggerLabel(TriggerType type) {
  switch (type) {
    case TriggerType.firstReview:
      return 'First Review';
    case TriggerType.riskSignal:
      return 'Risk Signal';
    case TriggerType.criticalLow:
      return 'Critical Low';
    case TriggerType.overconfidence:
      return 'Overconfidence';
    case TriggerType.underconfidence:
      return 'Underconfidence';
    case TriggerType.positiveMomentum:
      return 'Positive Momentum';
    case TriggerType.strongOutcome:
      return 'Strong Outcome';
    case TriggerType.reviewGap:
      return 'Review Gap';
    case TriggerType.manual:
      return 'Manual Note';
  }
}
