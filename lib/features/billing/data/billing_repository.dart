import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/billing/data/models/subscription.dart';

class BillingRepository {
  const BillingRepository(this._ref);

  final Ref _ref;

  /// Returns the current user's workspace_id, creating a workspace first if
  /// the user has never subscribed before (no subscription row yet).
  Future<String> ensureWorkspaceExists() async {
    // Fast path: workspace already linked via subscriptions table.
    final existing = await _ref.read(currentWorkspaceProvider.future);
    if (existing != null) return existing;

    // New user — create the workspace row directly.
    // Exception to no-raw-tables rule: no RPC exists for this operation.
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final result = await supabase
        .rpc('create_personal_workspace_for_current_user', params: {
          'workspace_name': user.email ?? 'My Workspace',
        });

    return result as String;
  }

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
    final session = supabase.auth.currentSession;
    final token = session?.accessToken ?? '';

    final response = await http.post(
      Uri.parse('https://omazuyditjbtoupmipcr.supabase.co/functions/v1/create-checkout-session'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'price_id': priceId,
        'workspace_id': workspaceId,
      }),
    );

    debugPrint('Checkout response status: ${response.statusCode}');
    debugPrint('Checkout response body: ${response.body}');

    final data = jsonDecode(response.body);
    final url = data['url'] as String?;

    if (url == null) throw Exception('No URL in checkout response: ${response.body}');
    return url;
  }

  /// Calls the create-checkout-session Edge Function for the Team plan,
  /// passing seat count and invited email addresses.
  Future<String> createTeamCheckoutSession({
    required String priceId,
    required String workspaceId,
    required int seatCount,
    required List<String> invitedEmails,
    required String successUrl,
    required String cancelUrl,
  }) async {
    final session = supabase.auth.currentSession;
    final token = session?.accessToken ?? '';

    final response = await http.post(
      Uri.parse('https://omazuyditjbtoupmipcr.supabase.co/functions/v1/create-checkout-session'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'price_id': priceId,
        'workspace_id': workspaceId,
        'seat_count': seatCount,
        'invited_emails': invitedEmails,
      }),
    );

    debugPrint('Team checkout response status: ${response.statusCode}');
    debugPrint('Team checkout response body: ${response.body}');

    final data = jsonDecode(response.body);
    final url = data['url'] as String?;

    if (url == null) {
      throw Exception('No URL in checkout response: ${response.body}');
    }
    return url;
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
