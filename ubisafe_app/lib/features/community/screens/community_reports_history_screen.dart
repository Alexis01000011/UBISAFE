import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/community_report.dart';

/// ☆ [iter.2] Screen showing the current user's submitted community reports.
class CommunityReportsHistoryScreen extends ConsumerWidget {
  const CommunityReportsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: use a provider that queries Firestore for the current user's reports.
    const List<CommunityReport> reports = [];

    return Scaffold(
      appBar: AppBar(title: const Text('Mis reportes')),
      body: reports.isEmpty
          ? const Center(child: Text('Aún no tienes reportes'))
          : ListView.builder(
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                return ListTile(
                  leading: const Icon(Icons.flag),
                  title: Text(report.category),
                  subtitle: Text(report.description),
                  trailing: Text('${report.votes} votos'),
                );
              },
            ),
    );
  }
}
