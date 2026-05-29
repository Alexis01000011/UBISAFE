class GroupStay {
  const GroupStay({
    required this.id,
    required this.vendorUid,
    required this.locationLat,
    required this.locationLng,
    required this.startAt,
    required this.endAt,
    required this.durationMinutes,
    required this.status,
    this.cancellationReason,
    this.attendeesCount = 0,
    this.riskLevelAtCreation,
    this.hasAttended,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String vendorUid;
  final double locationLat;
  final double locationLng;
  final String startAt;
  final String endAt;
  final int durationMinutes;
  final String status;
  final String? cancellationReason;
  final int attendeesCount;
  final String? riskLevelAtCreation;
  final bool? hasAttended;
  final String? createdAt;
  final String? updatedAt;

  bool get isActive => status == 'scheduled' || status == 'active';

  factory GroupStay.fromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>? ?? {};
    return GroupStay(
      id: json['id'] as String,
      vendorUid: json['vendor_uid'] as String,
      locationLat: (loc['lat'] as num).toDouble(),
      locationLng: (loc['lng'] as num).toDouble(),
      startAt: json['start_at'] as String,
      endAt: json['end_at'] as String,
      durationMinutes: json['duration_minutes'] as int,
      status: json['status'] as String,
      cancellationReason: json['cancellation_reason'] as String?,
      attendeesCount: (json['attendees_count'] as num?)?.toInt() ?? 0,
      riskLevelAtCreation: json['risk_level_at_creation'] as String?,
      hasAttended: json['has_attended'] as bool?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

/// Wraps the server response for POST /group-stays.
///
/// HTTP 200 → [stay] es null y [warning] tiene los datos de la zona MEDIUM/LOW.
///   No se creó nada; el cliente debe re-POST con acknowledged_risk_warning=true.
/// HTTP 201 → [stay] es el GroupStay creado; [warning] es null.
class CreateGroupStayResponse {
  const CreateGroupStayResponse({this.stay, this.warning});

  /// Null cuando el servidor devuelve 200 esperando confirmación del vendedor.
  final GroupStay? stay;

  /// Non-null cuando hay zona MEDIUM/LOW y aún no se ha confirmado.
  /// Keys: 'risk_level' (String), 'risk_zone_id' (String).
  final Map<String, dynamic>? warning;

  factory CreateGroupStayResponse.fromJson(Map<String, dynamic> json) {
    final stayJson = json['stay'] as Map<String, dynamic>?;
    return CreateGroupStayResponse(
      stay: stayJson != null ? GroupStay.fromJson(stayJson) : null,
      warning: json['warning'] as Map<String, dynamic>?,
    );
  }
}
