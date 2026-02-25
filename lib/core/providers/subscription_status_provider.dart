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

  // TODO: switch to user_visible_subscriptions view once confirmed present
  // in migrations, or replace with an RPC call:
  //   final result = await supabase.rpc('get_subscription_status');
  //
  // Current implementation reads from user_visible_subscriptions.
  // If the view does not exist this will throw; update the query accordingly.
  // Valid tier values from the schema: 'individual', 'team', 'coach'.
  // The status column (not tier) drives the gate — valid values: 'active', 'inactive'.
  final response = await supabase
      .from('user_visible_subscriptions')
      .select('status')
      .eq('user_id', userId)
      .maybeSingle();

  final status = response?['status'] as String?;
  return switch (status) {
    'active' => SubscriptionStatus.active,
    _ => SubscriptionStatus.inactive,
  };
});
