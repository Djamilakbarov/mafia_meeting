import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'waiting_room_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  bool _isLoading = false;
  late String _playerName;
  String _roomCode = '';

  @override
  void initState() {
    super.initState();
    _loadPlayerName();
    _generateRoomCode();
  }

  Future<void> _loadPlayerName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _playerName = prefs.getString('playerName') ?? 'Player';
    });
  }

  void _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    _roomCode = List.generate(
            6,
            (index) =>
                chars[(DateTime.now().microsecond + index * 3) % chars.length])
        .join();
  }

  Future<void> _createRoom() async {
    setState(() => _isLoading = true);

    final roomRef =
        FirebaseFirestore.instance.collection('rooms').doc(_roomCode);

    await roomRef.set({
      'roomCode': _roomCode,
      'host': _playerName,
      'players': [_playerName],
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() => _isLoading = false);

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              WaitingRoomScreen(roomCode: _roomCode, playerName: _playerName),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Создание комнаты')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 50),
                  Text("Код вашей комнаты:",
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  SelectableText(_roomCode,
                      style: const TextStyle(
                          fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _createRoom,
                    child: const Text("Создать комнату и продолжить"),
                  ),
                ],
              ),
      ),
    );
  }
}
