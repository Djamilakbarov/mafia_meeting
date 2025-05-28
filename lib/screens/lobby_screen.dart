import '../widgets/ads_banner_widget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  final Function toggleTheme;
  final bool isDarkMode;

  const LobbyScreen(
      {super.key, required this.toggleTheme, required this.isDarkMode});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final TextEditingController _roomCodeController = TextEditingController();
  final TextEditingController _playerNameController = TextEditingController();
  int _nightDuration = 15;
  int _discussionDuration = 30;
  int _votingDuration = 20;

  Future<void> _createRoom() async {
    final roomCode = _roomCodeController.text.trim();
    final playerName = _playerNameController.text.trim();

    if (roomCode.isEmpty || playerName.isEmpty) return;

    await FirebaseFirestore.instance.collection('rooms').doc(roomCode).set({
      'gamePhase': 'night',
      'nightActions': {},
      'phaseResult': {},
      'votes': {},
      'roomSettings': {
        'nightDuration': _nightDuration,
        'discussionDuration': _discussionDuration,
        'votingDuration': _votingDuration,
      },
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          roomCode: roomCode,
          playerName: playerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => widget.toggleTheme(),
        child: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
      ),
      appBar: AppBar(title: const Text('Создать комнату')),
      body: Column(
        children: const [
          AdsBannerWidget(),
        ],
        mainAxisSize: MainAxisSize.min,
        childrenOverflow: Overflow.visible,
        children: [
          // Вставка виджета баннера
          AdsBannerWidget(),
        ],
        children:
 Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

          const SizedBox(height: 24),
          Text('Static Rooms', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _joinStaticRoom('russian_room'),
            icon: Icon(Icons.people),
            label: Text('🇷🇺 Русскоязычные'),
          ),
          ElevatedButton.icon(
            onPressed: () => _joinStaticRoom('english_room'),
            icon: Icon(Icons.people_outline),
            label: Text('🇬🇧 English Room'),
          ),
          ElevatedButton.icon(
            onPressed: () => _joinStaticRoom('chayhana_room'),
            icon: Icon(Icons.emoji_food_beverage),
            label: Text('🍵 Чайхана'),
          ),
                TextField(
              controller: _roomCodeController,
              decoration: const InputDecoration(labelText: 'Код комнаты'),
            ),
            TextField(
              controller: _playerNameController,
              decoration: const InputDecoration(labelText: 'Ваше имя'),
            ),
            const SizedBox(height: 20),
            Text('⏱ Время фаз (в секундах)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ночь:'),
                DropdownButton<int>(
                  value: _nightDuration,
                  items: [10, 15, 20, 30].map((int val) {
                    return DropdownMenuItem<int>(
                      value: val,
                      child: Text('$val сек'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _nightDuration = val!),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Обсуждение:'),
                DropdownButton<int>(
                  value: _discussionDuration,
                  items: [20, 30, 45, 60].map((int val) {
                    return DropdownMenuItem<int>(
                      value: val,
                      child: Text('$val сек'),
                    );
                  }).toList(),
                  onChanged: (val) =>
                      setState(() => _discussionDuration = val!),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Голосование:'),
                DropdownButton<int>(
                  value: _votingDuration,
                  items: [10, 15, 20, 30].map((int val) {
                    return DropdownMenuItem<int>(
                      value: val,
                      child: Text('$val сек'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _votingDuration = val!),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _createRoom,
              child: const Text('Создать и войти'),
            ),
          ],
        ),
      ),
    );
  }
}