import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import 'game_screen.dart';
import 'settings_screen.dart';

class LobbyScreen extends StatefulWidget {
  final void Function() toggleTheme;
  final bool isDarkMode;

  const LobbyScreen({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final TextEditingController _roomCodeController = TextEditingController();
  late TextEditingController _nameController;
  String? _roomCode;
  String _playerName = "Player";

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _loadPlayerName();
  }

  Future<void> _loadPlayerName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('playerName');
    final generated = _generateRandomName();
    setState(() {
      _playerName = savedName ?? generated;
      _nameController.text = _playerName;
    });
  }

  Future<void> _savePlayerName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('playerName', name);
  }

  String _generateRandomName() {
    final number = Random().nextInt(900) + 100;
    return "Player$number";
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> _createRoom() async {
    final code = _generateRoomCode();
    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(code);
    await roomRef.set({
      'players': [_playerName],
      'host': _playerName,
      'started': false,
    });
    setState(() {
      _roomCode = code;
    });
  }

  Future<void> _joinRoom() async {
    final code = _roomCodeController.text.trim().toUpperCase();
    if (code.length != 6) {
      _showError(AppLocalizations.of(context)!.invalidRoomCode);
      return;
    }

    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(code);
    final snapshot = await roomRef.get();

    if (!snapshot.exists) {
      _showError(AppLocalizations.of(context)!.invalidRoomCode);
      return;
    }

    await roomRef.update({
      'players': FieldValue.arrayUnion([_playerName])
    });

    setState(() {
      _roomCode = code;
    });
  }

  Future<void> _joinStaticRoom(String roomCode) async {
    final roomRef =
        FirebaseFirestore.instance.collection('rooms').doc(roomCode);
    final snapshot = await roomRef.get();

    if (!snapshot.exists) {
      await roomRef.set({
        'players': [_playerName],
        'host': _playerName,
        'started': false,
      });
    } else {
      await roomRef.update({
        'players': FieldValue.arrayUnion([_playerName])
      });
    }

    setState(() {
      _roomCode = roomCode;
    });
  }

  Future<void> _leaveRoom() async {
    if (_roomCode != null) {
      final roomRef =
          FirebaseFirestore.instance.collection('rooms').doc(_roomCode);
      await roomRef.update({
        'players': FieldValue.arrayRemove([_playerName])
      });
    }

    setState(() {
      _roomCode = null;
    });
  }

  void _startGame() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          roomCode: _roomCode!,
          playerName: _playerName,
        ),
      ),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.error),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.lobby),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    isDarkMode: widget.isDarkMode,
                    onThemeChanged: (val) => widget.toggleTheme(),
                    onLocaleChanged: (locale) =>
                        MafiaMeetingApp.setLocale(context, locale),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _roomCode == null
            ? SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Ваше имя",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        _playerName = value;
                        _savePlayerName(value);
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _createRoom,
                      child: Text(loc.createRoom),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _roomCodeController,
                      decoration: InputDecoration(
                        labelText: loc.roomCode,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _joinRoom,
                      child: Text(loc.joinRoom),
                    ),
                    const SizedBox(height: 30),
                    Divider(),
                    const SizedBox(height: 10),
                    Text("Стационарные комнаты",
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => _joinStaticRoom("RUS001"),
                      child: const Text("Комната для русскоязычных"),
                    ),
                    ElevatedButton(
                      onPressed: () => _joinStaticRoom("ENG001"),
                      child: const Text("Room for English"),
                    ),
                    ElevatedButton(
                      onPressed: () => _joinStaticRoom("CHAT01"),
                      child: const Text("Чайхана"),
                    ),
                  ],
                ),
              )
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('rooms')
                    .doc(_roomCode)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  final players = List<String>.from(data?['players'] ?? []);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${loc.roomCode}: $_roomCode",
                          style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 20),
                      Text(loc.players, style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 10),
                      ...players
                          .map((p) => ListTile(
                                leading: const Icon(Icons.person),
                                title: Text(p),
                              ))
                          .toList(),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: _startGame,
                            child: Text(loc.startGame),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey),
                            onPressed: _leaveRoom,
                            child: const Text("Выйти"),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
