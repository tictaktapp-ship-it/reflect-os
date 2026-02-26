class Subscription {
  const Subscription({
    required this.id,
    required this.workspaceId,
    required this.userId,
    required this.tier,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    required this.status,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.cancelAtPeriodEnd,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String workspaceId;
  final String userId;
  final String tier;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final String status;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == 'active';
  bool get isCancelling => cancelAtPeriodEnd;

  String get tierDisplayName => switch (tier.toLowerCase()) {
        'individual' => 'Individual',
        'team' => 'Team',
        'enterprise' => 'Enterprise',
        _ => tier,
      };

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        id: json['id'] as String,
        workspaceId: json['workspace_id'] as String,
        userId: json['user_id'] as String,
        tier: json['tier'] as String,
        stripeCustomerId: json['stripe_customer_id'] as String?,
        stripeSubscriptionId: json['stripe_subscription_id'] as String?,
        status: json['status'] as String,
        currentPeriodStart:
            DateTime.parse(json['current_period_start'] as String),
        currentPeriodEnd: DateTime.parse(json['current_period_end'] as String),
        cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
