class Subscription {
  const Subscription({
    required this.id,
    required this.buyerUid,
    required this.vendorUid,
    required this.active,
    this.createdAt,
    this.cancelledAt,
    this.cancellationReason,
  });

  final String id;
  final String buyerUid;
  final String vendorUid;
  final bool active;
  final String? createdAt;
  final String? cancelledAt;
  final String? cancellationReason;

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        id: json['id'] as String,
        buyerUid: json['buyer_uid'] as String,
        vendorUid: json['vendor_uid'] as String,
        active: json['active'] as bool,
        createdAt: json['created_at'] as String?,
        cancelledAt: json['cancelled_at'] as String?,
        cancellationReason: json['cancellation_reason'] as String?,
      );
}
