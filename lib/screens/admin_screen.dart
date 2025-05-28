
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_logs_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final TextEditingController _bannerUrlController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  bool _isActive = true;

  Future<void> _saveBanner() async {
    await FirebaseFirestore.instance.collection('ads').add({
      'bannerUrl': _bannerUrlController.text.trim(),
      'link': _linkController.text.trim(),
      'isActive': _isActive,
      'timestamp': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Баннер добавлен')),
    );
    _bannerUrlController.clear();
    _linkController.clear();
    setState(() => _isActive = true);
  }

  List<Map<String, dynamic>> users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    final data = snapshot.docs.map((doc) {
      final d = doc.data();
      return {
        'name': doc.id,
        'likes': d['totalLikes'] ?? 0,
        'games': d['gamesPlayed'] ?? 0,
      };
    }).toList();

    setState(() {
      users = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('👮 Админ-панель')),
      body: Column(
        children: [

          const Divider(height: 32),
          const Text('📣 Добавить рекламу', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          const Text('URL баннера (картинка или gif):'),
          TextField(
            controller: _bannerUrlController,
            decoration: const InputDecoration(hintText: 'https://...'),
          ),
          const SizedBox(height: 12),
          const Text('Ссылка при нажатии (необязательно):'),
          TextField(
            controller: _linkController,
            decoration: const InputDecoration(hintText: 'https://...'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Активен?'),
              Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _saveBanner,
            child: const Text('💾 Сохранить баннер'),
          ),

          Container(
            width: double.infinity,
            color: Colors.amber[100],
            padding: const EdgeInsets.all(12),
            child: Row(
              children: const [
                Icon(Icons.campaign, color: Colors.orange),
                SizedBox(width: 10),
                Expanded(child: Text('🎯 РЕКЛАМА: Участвуй в турнире Mafia Challenge и выиграй призы!', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminLogsScreen()),
              );
            },
            child: const Text('📜 Посмотреть логи админов'),
          ),
          const SizedBox(height: 10),
          const Text('📋 Пользователи', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(
              children: users.map((user) {
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(user['name']),
                  subtitle: Text('Игр: ${user['games']} | Лайков: ${user['likes']}'),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}