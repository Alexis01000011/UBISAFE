import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/community_report.dart';

/// ☆ [iter.2] CU-05 — Submit a new community report and visualise on map.
class CommunityReportModule {
  CommunityReportModule(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('community_reports');

  /// Creates a new [CommunityReport] and returns its Firestore ID.
  Future<String> submit(CommunityReport report) async {
    final doc = await _col.add(report.toMap());
    return doc.id;
  }

  /// Stream of all active (non-dismissed) community reports.
  Stream<List<CommunityReport>> watchActive() => _col
      .where('status', isEqualTo: CommunityReportStatus.active.name)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => CommunityReport.fromMap(d.id, d.data()))
            .toList(),
      );

  /// Stream of a specific user's reports.
  Stream<List<CommunityReport>> watchByUser(String uid) => _col
      .where('reporter_uid', isEqualTo: uid)
      .orderBy('created_at', descending: true)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => CommunityReport.fromMap(d.id, d.data()))
            .toList(),
      );
}

final communityReportModuleProvider = Provider<CommunityReportModule>((ref) {
  return CommunityReportModule(FirebaseFirestore.instance);
});
