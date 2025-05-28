import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  final String playerName;
  const ProfileScreen({super.key, required this.playerName});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int wins = 0;
  int losses = 0;
  int rating = 0;
  int likesReceived = 0;
  List<Map<String, dynamic>> history = [];
  int bestPlayerCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.playerName)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        wins = data['wins'] ?? 0;
        losses = data['losses'] ?? 0;
        rating = data['rating'] ?? 0;
        likesReceived = data['likesReceived'] ?? 0;
        history = List<Map<String, dynamic>>.from(data['history'] ?? []);
        bestPlayerCount = history.where((game) => game['bestPlayer'] == widget.playerName).length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Профиль: ${widget.playerName}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🏆 Победы: $wins'),
            Text('💀 Поражения: $losses'),
            Text('❤️ Рейтинг: $rating'),
            const SizedBox(height: 16),
            Text('История игр:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: history.isEmpty
                  ? Text('Нет данных')
                  : ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final game = history[index];
                        return ListTile(
                          title: Text(
                              'Роль: ${game['role']} — ${game['result'] == 'win' ? '🏆 Победа' : '💀 Поражение'}'),
                          subtitle: Text(game['date'] ?? ''),
                          trailing: game['bestPlayer'] == widget.playerName
                              ? const Text('🏅')
                              : null,
                        );
                      },
                    ),
            )
          ],
        ),
      ),
    );
  }
}
