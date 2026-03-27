import 'package:flutter/foundation.dart';
import 'package:reflect_os/features/coaching/data/models/coaching_session.dart';

@immutable
class AttentionDecision {
  const AttentionDecision({
    required this.clientUserId,
    required this.clientName,
    required this.decisionId,
    required this.decisionTitle,
    required this.healthState,
  });

  final String clientUserId;
  final String clientName;
  final String decisionId;
  final String decisionTitle;
  final String healthState;
}

@immutable
class CrossClientDashboard {
  const CrossClientDashboard({
    required this.totalActiveDecisions,
    required this.overdueReviews,
    required this.sessionsThisMonth,
    required this.attentionNeeded,
    required this.upcomingSessions,
  });

  const CrossClientDashboard.empty()
      : totalActiveDecisions = 0,
        overdueReviews = 0,
        sessionsThisMonth = 0,
        attentionNeeded = const [],
        upcomingSessions = const [];

  final int totalActiveDecisions;
  final int overdueReviews;
  final int sessionsThisMonth;
  final List<AttentionDecision> attentionNeeded;
  final List<CoachingSession> upcomingSessions;
}
