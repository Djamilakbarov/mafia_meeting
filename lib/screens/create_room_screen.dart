import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'waiting_room_screen.dart';
import 'dart:math';
import '../models/player_model.dart';
import '../models/role_enum.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class CreateRoomScreen extends StatefulWidget {
  final String currentUserId; // НОВОЕ: Принимаем UID
  final String playerName; // НОВОЕ: Принимаем имя игрока
  final Future<void> Function(bool) toggleTheme; // <-- Добавлено
  final bool isDarkMode; // <-- Добавлено

  const CreateRoomScreen({
    super.key,
    required this.currentUserId,
    required this.playerName,
    required this.toggleTheme, // <-- Добавлено
    required this.isDarkMode, // <-- Добавлено
  });

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  bool _isLoading = false;
  String _roomCode = '';
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _roomCode = _generateRandomRoomCode(); // Генерируем код сразу
  }

  String _generateRandomRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(6, (index) => chars[_random.nextInt(chars.length)])
        .join();
  }

  Future<void> _createRoom() async {
    final loc = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    final roomRef =
        FirebaseFirestore.instance.collection('rooms').doc(_roomCode);

    try {
      await roomRef.set({
        'roomCode': _roomCode,
        'host': widget.playerName, // Используем имя, переданное через виджет
        'players': [
          Player(
                  id: widget.currentUserId,
                  name: widget.playerName,
                  role: Role.villager)
              .toMap()
        ],
        'createdAt': FieldValue.serverTimestamp(),
        'roomSettings': {
          'discussionDuration': 120,
          'votingDuration': 60,
          'nightDuration': 15,
        },
        'gamePhase': 'waiting',
      });

      setState(() => _isLoading = false);

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => WaitingRoomScreen(
              roomCode: _roomCode,
              playerName: widget.playerName,
              currentUserId: widget.currentUserId, // Передаем UID
              toggleTheme: widget.toggleTheme, // <-- Передаем
              isDarkMode: widget.isDarkMode, // <-- Передаем
            ),
          ),
        );
      }
    } catch (e) {
      print("Ошибка при создании комнаты: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.createRoomError}: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.createRoom)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 50),
                  Text(loc.roomCodeIs,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  SelectableText(_roomCode,
                      style: const TextStyle(
                          fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _createRoom,
                    child: Text(loc.createAndJoin),
                  ),
                ],
              ),
      ),
    );
  }
}
