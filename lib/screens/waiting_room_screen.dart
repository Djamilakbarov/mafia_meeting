import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'game_screen.dart';
// Убедись, что путь правильный
import '../models/role_enum.dart';

class WaitingRoomScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;

  const WaitingRoomScreen({
    super.key,
    required this.roomCode,
    required this.playerName,
  });

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  int _discussionTime = 120;

  late Stream<DocumentSnapshot<Map<String, dynamic>>> _roomStream;

  @override
  void initState() {
    super.initState();
    _roomStream = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .snapshots();
  }

  void _startGame(List<String> players) async {
    List<Role> roles = _generateRoles(players.length);
    roles.shuffle();

    List<Map<String, dynamic>> assignedPlayers = [];
    for (int i = 0; i < players.length; i++) {
      assignedPlayers.add({
        'name': players[i],
        'role': roles[i].name,
        'isAlive': true,
      });
    }

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .update({
      'started': true,
      'phase': 'night',
      'players': assignedPlayers,
    });
  }

  List<Role> _generateRoles(int count) {
    List<Role> result = [];
    if (count >= 5) {
      result.addAll([
        Role.mafia,
        Role.doctor,
        Role.detective,
        Role.maniac,
      ]);
    }
    while (result.length < count) {
      result.add(Role.villager);
    }
    return result;
  }

  void _leaveRoom() async {
    final docRef =
        FirebaseFirestore.instance.collection('rooms').doc(widget.roomCode);
    final doc = await docRef.get();
    final data = doc.data();
    if (data != null) {
      final players = data['players'] as List;
      final newPlayers = players.where((p) {
        if (p is String) return p != widget.playerName;
        if (p is Map) return p['name'] != widget.playerName;
        return true;
      }).toList();
      await docRef.update({'players': newPlayers});
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.lobby)),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _roomStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("${loc.error}: ${snapshot.error}"));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text(loc.invalidRoomCode));
          }

          final roomData = snapshot.data!.data()!;
          final dynamic rawPlayers = roomData['players'];
          final players = (rawPlayers as List)
              .map((p) {
                if (p is String) return p;
                if (p is Map) return p['name'] ?? '';
                return '';
              })
              .where((p) => p.isNotEmpty)
              .cast<String>()
              .toList();

          final host = roomData['host'];
          final started = roomData['started'] ?? false;

          if (started) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => GameScreen(
                    playerName: widget.playerName,
                    roomCode: widget.roomCode,
                  ),
                ),
              );
            });
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Text('⏱ Выберите время обсуждения:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<int>(
                value: _discussionTime,
                items: [120, 180, 240]
                    .map((int value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text('$value секунд'),
                        ))
                    .toList(),
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _discussionTime = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              Text("${loc.roomCode}: ${widget.roomCode}",
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Text(loc.players, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: players.length,
                  itemBuilder: (_, index) => ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(players[index]),
                    trailing: players[index] == host
                        ? const Icon(Icons.star, color: Colors.amber)
                        : null,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (widget.playerName == host)
                    ElevatedButton(
                      onPressed: players.length >= 4
                          ? () => _startGame(players)
                          : null,
                      child: Text(loc.startGame),
                    ),
                  ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                    onPressed: _leaveRoom,
                    child: Text(loc.leave),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}
