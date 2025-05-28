import 'profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;
  final Function(Locale) onLocaleChanged;

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.onLocaleChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _isDark;
  late String _playerName;
  late TextEditingController _nameController;
  late Locale _currentLocale;
  List<Map<String, dynamic>> gameHistory = [];

  @override
  void initState() {
    super.initState();
    _isDark = widget.isDarkMode;
    _nameController = TextEditingController(text: '');
    _currentLocale = const Locale('en');
    _loadPreferences();
    _loadHistory();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('playerName') ?? "Player";
    final localeCode = prefs.getString('locale') ?? 'en';

    setState(() {
      _playerName = name;
      _nameController.text = name;
      _currentLocale = Locale(localeCode);
    });
  }

  Future<void> _saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('playerName', name);
    setState(() {
      _playerName = name;
    });
  }

  void _changeLanguage(Locale? locale) {
    if (locale == null) return;
    widget.onLocaleChanged(locale);
    setState(() {
      _currentLocale = locale;
    });
  }

  Future<void> _loadHistory() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('history')
        .orderBy('timestamp', descending: true)
        .get();

    final history = snapshot.docs
        .where((doc) {
          final players = List<Map<String, dynamic>>.from(doc['players']);
          return players.any((p) => p['name'] == _playerName);
        })
        .map((doc) => doc.data())
        .toList();

    setState(() {
      gameHistory = history;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.settings!),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            leading: Icon(Icons.person),
            title: Text('Мой профиль'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(playerName: _playerName),
                ),
              );
            },
          ),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: loc.player),
            onChanged: (value) => _saveName(value),
          ),
          const SizedBox(height: 30),
          SwitchListTile(
            title: Text(loc.darkTheme!),
            value: _isDark,
            onChanged: (value) {
              setState(() => _isDark = value);
              widget.onThemeChanged(value);
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.admin_panel_settings),
            title: Text('Админ-панель'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminLogin()),
              );
            },
          ),
          const Divider(),
          const Text("📜 История игр",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...gameHistory.map((game) {
            final date = DateFormat.yMd()
                .add_jm()
                .format(DateTime.parse(game['timestamp']));
            final eliminated = game['eliminated'] ?? 'Unknown';
            final room = game['roomCode'] ?? '';
            final bestPlayer = game['bestPlayer'] ?? 'N/A';
            final likes =
                Map<String, dynamic>.from(game['likesReceived'] ?? {});
            return Card(
              child: ListTile(
                title: Text("Room: $room - $date"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        "Eliminated: $eliminated | Players: \${game['players'].length}"),
                    Text("⭐ Best Player: $bestPlayer"),
                    if (likes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text("❤️ Likes: " +
                            likes.entries
                                .map((e) => "\${e.key} (\${e.value})")
                                .join(", ")),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
