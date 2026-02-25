import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/providers/auth_state_provider.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';

enum SubscriptionStatus { active, inactive, unknown }

final subscriptionStatusProvider =
    FutureProvider<SubscriptionStatus>((ref) async {
  final authStatus = ref.watch(authStateProvider);
  final auth = authStatus.valueOrNull;

  if (auth is! AuthAuthenticated) {
    return SubscriptionStatus.unknown;
  }

  final userId = auth.session.user.id;

  // Exception to the no-raw-tables rule: there is no user_visible_subscriptions
  // view in the schema. The subscriptions table is queried directly here.
  // RLS on the subscriptions table ensures users can only read their own row.
  // Valid tier values: 'individual', 'team', 'coach'.
  // Valid status values: 'active', 'inactive'.
  final response = await supabase
      .from('subscriptions')
      .select('status')
      .eq('user_id', userId)
      .maybeSingle();

  final status = response?['status'] as String?;
  return switch (status) {
    'active' => SubscriptionStatus.active,
    _ => SubscriptionStatus.inactive,
  };
});
