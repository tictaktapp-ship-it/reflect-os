import 'dart:convert';

import 'package:reflect_os/core/supabase/supabase_client.dart';

/// Manages the 30-day activation notification sequence for new users.
///
/// All public methods are fire-and-forget safe — wrap calls with `.ignore()`
/// so that transient DB errors never surface to the user.
class ActivationSequenceService {
  const ActivationSequenceService._();

  // ── Sequence seeding ──────────────────────────────────────────────────────

  /// Called once after signup. Writes the tracking row and seeds all
  /// notification_queue entries. Idempotent: safe to call twice.
  static Future<void> seedSequence(
      String userId, DateTime signupDate) async {
    await supabase.from('user_activation_sequence').upsert({
      'user_id': userId,
      'signup_date': signupDate.toUtc().toIso8601String(),
      'sequence_seeded_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');

    // Insert all notifications in one batch. If duplicate notifications
    // already exist (e.g. from a retry), the DB will reject them — that's fine.
    try {
      final notifications = _buildSequence(userId, signupDate);
      await supabase.from('notification_queue').insert(notifications);
    } catch (_) {
      // Idempotency: if rows already exist the insert will fail — ignore.
    }
  }

  // ── Decision tracking ─────────────────────────────────────────────────────

  /// Called every time the user logs a decision.
  /// Increments the counter, stamps first_decision_logged_at on the first
  /// decision, and cancels habit prompts once the user logs 5 or more.
  static Future<void> trackDecisionLogged(String userId) async {
    final row = await supabase
        .from('user_activation_sequence')
        .select('decisions_logged_count, first_decision_logged_at')
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return; // Sequence not seeded — user may have signed up before this feature.

    final currentCount = (row['decisions_logged_count'] as int?) ?? 0;
    final newCount = currentCount + 1;
    final isFirst = row['first_decision_logged_at'] == null;

    await supabase.from('user_activation_sequence').update({
      'decisions_logged_count': newCount,
      if (isFirst)
        'first_decision_logged_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('user_id', userId);

    // Once engaged (5+ decisions), cancel remaining habit prompts.
    // Insight, review, lockIn, and milestone notifications are kept.
    if (newCount >= 5) {
      await supabase
          .from('notification_queue')
          .update({'status': 'Cancelled'})
          .eq('user_id', userId)
          .eq('notification_type', 'activation_habit')
          .eq('status', 'Pending');
    }
  }

  // ── Sequence builder ──────────────────────────────────────────────────────

  static List<Map<String, dynamic>> _buildSequence(
      String userId, DateTime signupDate) {
    Map<String, dynamic> n(
      int daysOffset,
      String type,
      String title,
      String body,
    ) =>
        {
          'user_id': userId,
          'notification_type': type,
          'title': title,
          'body': body,
          'scheduled_for': signupDate
              .add(Duration(days: daysOffset))
              .toUtc()
              .toIso8601String(),
          'status': 'Pending',
          'metadata_jsonb': jsonEncode({
            'sequence': '30_day_activation',
            'day': daysOffset,
          }),
        };

    return [
      // ── Habit prompts (days 1-3) ─────────────────────────────────────────
      n(
        1,
        'activation_habit',
        'Log your next decision',
        'Reflect OS gets smarter the more you use it. '
            'Log one decision today — it takes under a minute.',
      ),
      n(
        2,
        'activation_habit',
        'Capture a decision from today',
        'Good decision-makers track their choices. '
            'What decision did you make or face today?',
      ),
      n(
        3,
        'activation_habit',
        'Keep the streak going',
        "You're building a valuable decision record. "
            'Log one more decision to continue.',
      ),

      // ── Insight (day 7) ──────────────────────────────────────────────────
      n(
        7,
        'activation_insight',
        'Your decision patterns are starting to form',
        'After a week with Reflect OS, you\'re building '
            'a picture of how you make decisions. '
            'Open the app to see your confidence trends.',
      ),

      // ── Pattern hint (day 10) ────────────────────────────────────────────
      n(
        10,
        'activation_pattern',
        'A pattern is emerging',
        'You tend to assign similar confidence levels '
            'to a type of decision. '
            'Review your decisions to spot the pattern.',
      ),

      // ── Review prompt (day 14) ───────────────────────────────────────────
      n(
        14,
        'activation_review',
        'Your first decision is due for review',
        'Two weeks ago you logged a decision. '
            "It's time to see what actually happened. "
            'Open Reflect OS to record your outcome.',
      ),

      // ── Behaviour lock-in (day 21) ───────────────────────────────────────
      n(
        21,
        'activation_lockIn',
        "You're 3 weeks in — here's what we've noticed",
        'Reflect OS has been quietly analysing your '
            'decisions. Open the app to see your first '
            'accuracy and calibration insights.',
      ),

      // ── Milestone (day 30) ───────────────────────────────────────────────
      n(
        30,
        'activation_milestone',
        '30 days of better decisions',
        "You've completed your first month with "
            'Reflect OS. Your decision intelligence '
            'score is now available on your dashboard.',
      ),
    ];
  }
}
