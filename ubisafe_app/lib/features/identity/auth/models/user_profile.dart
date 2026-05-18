class UserProfile {
  const UserProfile({
    required this.uid,
    this.name,
    this.phone,
    this.role,
    this.email,
    this.fcmToken,
    this.rideEnabled,
  });

  final String uid;
  final String? name;
  final String? phone;
  final String? role;
  final String? email;
  final String? fcmToken;
  final bool? rideEnabled;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        uid: json['uid'] as String,
        name: json['name'] as String?,
        phone: json['phone'] as String?,
        role: json['role'] as String?,
        email: json['email'] as String?,
        fcmToken: json['fcm_token'] as String?,
        rideEnabled: json['ride_enabled'] as bool?,
      );
}
