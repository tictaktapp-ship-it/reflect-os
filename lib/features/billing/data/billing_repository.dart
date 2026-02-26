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
}
