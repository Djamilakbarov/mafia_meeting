
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 Лидерборд'),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .orderBy('gamesWon', descending: true)
            .limit(20)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final users = snapshot.data!.docs;
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final data = users[index];
              return ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(data.id),
                subtitle: Text(
                  'Побед: ${data['gamesWon'] ?? 0} | Игр: ${data['gamesPlayed'] ?? 0} | Лайки: ${data['likesReceived'] ?? 0} | Лучший: ${data['bestPlayerCount'] ?? 0}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
