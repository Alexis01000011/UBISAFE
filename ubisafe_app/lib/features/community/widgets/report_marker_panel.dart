import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/community_report.dart';
import '../services/report_validation_module.dart';
import '../../../features/identity/auth/auth_module.dart';

/// ☆ [iter.2] Detail panel shown when the user taps a community report marker.
class ReportMarkerPanel extends ConsumerWidget {
  const ReportMarkerPanel({
    super.key,
    required this.report,
    required this.onClose,
  });

  final CommunityReport report;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);
    final validator = ref.read(reportValidationModuleProvider);

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.category,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
            Text(report.description),
            const SizedBox(height: 8),
            Text('Votos: ${report.votes}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.thumb_up),
                    label: const Text('Confirmar'),
                    onPressed: () {
                      final uid = userAsync.valueOrNull?.uid;
                      if (uid == null) return;
                      validator.vote(
                        reportId: report.id,
                        voterUid: uid,
                        voteType: VoteType.confirm,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.thumb_down),
                    label: const Text('Desestimar'),
                    onPressed: () {
                      final uid = userAsync.valueOrNull?.uid;
                      if (uid == null) return;
                      validator.vote(
                        reportId: report.id,
                        voterUid: uid,
                        voteType: VoteType.dismiss,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
