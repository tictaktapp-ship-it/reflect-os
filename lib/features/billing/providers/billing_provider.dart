import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/features/billing/data/billing_repository.dart';
import 'package:reflect_os/features/billing/data/models/subscription.dart';

final billingRepositoryProvider = Provider<BillingRepository>(
  (ref) => BillingRepository(ref),
);

final subscriptionProvider = FutureProvider<Subscription?>((ref) {
  return ref.read(billingRepositoryProvider).getSubscription();
});
