import 'package:equatable/equatable.dart';

class UserSubscription extends Equatable {
  final String userId;
  final bool isPremium;
  final String? planId;
  final String status;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final int remainingDays;

  const UserSubscription({
    required this.userId,
    required this.isPremium,
    this.planId,
    this.status = 'NONE',
    this.startedAt,
    this.expiresAt,
    this.remainingDays = 0,
  });

  bool get isActive => isPremium && (expiresAt == null || expiresAt!.isAfter(DateTime.now()));
  bool get isExpiringSoon => isActive && remainingDays <= 3;

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      userId: (json['userId'] ?? json['user_id']) as String? ?? '',
      isPremium: (json['isPremium'] ?? json['is_premium']) as bool? ?? false,
      planId: (json['premiumPlanId'] ?? json['planId'] ?? json['plan_id']) as String?,
      status: ((json['subscriptionStatus'] ?? json['status']) as String? ?? 'NONE').toUpperCase(),
      startedAt: json['subscriptionStartedAt'] != null
          ? DateTime.tryParse(json['subscriptionStartedAt'] as String)
          : (json['started_at'] != null ? DateTime.tryParse(json['started_at'] as String) : null),
      expiresAt: json['subscriptionExpiresAt'] != null
          ? DateTime.tryParse(json['subscriptionExpiresAt'] as String)
          : (json['expires_at'] != null ? DateTime.tryParse(json['expires_at'] as String) : null),
      remainingDays: (json['remainingDays'] ?? json['remaining_days'] as num?)?.toInt() ?? 0,
    );
  }

  factory UserSubscription.free({required String userId}) {
    return UserSubscription(
      userId: userId,
      isPremium: false,
      planId: null,
      status: 'NONE',
      remainingDays: 0,
    );
  }

  @override
  List<Object?> get props => [userId, isPremium, planId, status, expiresAt];
}

