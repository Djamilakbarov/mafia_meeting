import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_logs_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> users = [];
  bool _usersLoading = true;
  String? _usersError;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final loc = AppLocalizations.of(context)!;
    setState(() {
      _usersLoading = true;
      _usersError = null;
    });
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();
      if (mounted) {
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
          _usersLoading = false;
        });
      }
    } catch (e) {
      print("Ошибка при загрузке пользователей: $e");
      if (mounted) {
        setState(() {
          _usersError = '${loc.usersLoadError}: $e';
          _usersLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.usersLoadError}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.adminPanel)),
      body: Column(
        children: [
          const Divider(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminLogsScreen()),
              );
            },
            child: Text(loc.viewAdminLogs),
          ),
          const SizedBox(height: 10),
          Text(loc.users,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          _usersLoading
              ? const Center(child: CircularProgressIndicator())
              : _usersError != null
                  ? Center(
                      child: Text(_usersError!,
                          style: const TextStyle(color: Colors.red)))
                  : Expanded(
                      child: ListView(
                        children: users.map((user) {
                          return ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(user['name']),
                            subtitle: Text(
                                '${loc.games}: ${user['games']} | ${loc.likes}: ${user['likes']}'),
                          );
                        }).toList(),
                      ),
                    ),
        ],
      ),
    );
  }
}
