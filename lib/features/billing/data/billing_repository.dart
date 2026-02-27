import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/billing/data/models/subscription.dart';

class BillingRepository {
  const BillingRepository(this._ref);

  final Ref _ref;

  Future<Subscription?> getSubscription() async {
    final workspaceId = await _ref.read(currentWorkspaceProvider.future);
    if (workspaceId == null) return null;

    final row = await supabase
        .from('subscriptions')
        .select()
        .eq('workspace_id', workspaceId)
        .maybeSingle();

    if (row == null) return null;
    return Subscription.fromJson(row);
  }

  /// Calls the create-checkout-session Edge Function and returns the
  /// Stripe-hosted checkout URL.
  Future<String> createCheckoutSession({
    required String priceId,
    required String workspaceId,
    required String successUrl,
    required String cancelUrl,
  }) async {
    final response = await supabase.functions.invoke(
      'create-checkout-session',
      body: {
        'price_id': priceId,
        'workspace_id': workspaceId,
        'success_url': successUrl,
        'cancel_url': cancelUrl,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return data['url'] as String;
  }

  /// Calls the manage-subscription Edge Function and returns the
  /// Stripe Customer Portal URL.
  Future<String> manageSubscription({
    required String workspaceId,
    required String returnUrl,
  }) async {
    final response = await supabase.functions.invoke(
      'manage-subscription',
      body: {
        'workspace_id': workspaceId,
        'return_url': returnUrl,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return data['url'] as String;
  }
}
