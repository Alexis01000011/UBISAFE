import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum VoteType { confirm, dismiss }

/// ☆ [iter.2] CU-06 — Vote to confirm or dismiss a community report.
class ReportValidationModule {
  ReportValidationModule(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('community_reports');

  CollectionReference<Map<String, dynamic>> _votes(String reportId) =>
      _reports.doc(reportId).collection('votes');

  /// Cast or update a vote on [reportId] by [voterUid].
  Future<void> vote({
    required String reportId,
    required String voterUid,
    required VoteType voteType,
  }) async {
    final batch = _firestore.batch();

    final voteRef = _votes(reportId).doc(voterUid);
    batch.set(voteRef, {
      'voter_uid': voterUid,
      'vote': voteType.name,
      'voted_at': FieldValue.serverTimestamp(),
    });

    // Increment the appropriate counter atomically.
    final reportRef = _reports.doc(reportId);
    if (voteType == VoteType.confirm) {
      batch.update(reportRef, {'votes': FieldValue.increment(1)});
    } else {
      batch.update(reportRef, {'dismiss_votes': FieldValue.increment(1)});
    }

    await batch.commit();
  }
}

final reportValidationModuleProvider =
    Provider<ReportValidationModule>((ref) {
  return ReportValidationModule(FirebaseFirestore.instance);
});
