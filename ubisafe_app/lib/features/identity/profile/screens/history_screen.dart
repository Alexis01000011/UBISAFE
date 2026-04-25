import 'package:flutter/material.dart';

/// Displays the history of completed trips / stop requests for the current user.
///
/// [iter.2] Will also show community-report history and ride history.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: const Center(
        // TODO: fetch history from Firestore and display in a ListView.
        child: Text('Historial vacío'),
      ),
    );
  }
}
