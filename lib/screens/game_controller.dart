import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../models/player_model.dart';
import 'bot_manager.dart';
import '../models/role_enum.dart';

class GameController {
  static Future<void> simulateBotsIfNeeded(String roomCode) async {
    final roomRef =
        FirebaseFirestore.instance.collection('rooms').doc(roomCode);
    final snapshot = await roomRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.data();
    final List<dynamic> playerData = data?['players'] ?? [];
    final players = playerData.map((p) => Player.fromMap(p)).toList();

    if (players.length >= 8) return;

    final neededBots = 8 - players.length;
    final botNames = [
      'Zaur',
      'Zaur777',
      'Narmin',
      'Gunel',
      'Suleyman',
      'Aftandil',
      'Aleks',
      'Sarimsagov',
      'Sogan'
    ];
    final rand = Random();

    List<Role> availableRoles = List.from(Role.values);
    availableRoles.shuffle();

    for (int i = 0; i < neededBots; i++) {
      final botName = botNames[rand.nextInt(botNames.length)];
      final role = availableRoles.isNotEmpty
          ? availableRoles.removeLast()
          : Role.villager;
      players.add(Player(name: botName, role: role, isBot: true));
    }

    await roomRef.update({
      'players': players.map((p) => p.toMap()).toList(),
    });
  }

  static Future<void> calculateNightResult(
    String roomCode,
    List<Player> players,
    Map<String, dynamic> actions,
  ) async {
    await BotManager.simulateNightActions(roomCode, players);

    String? killed = actions['mafia'];
    String? healed = actions['doctor'];
    String? investigated = actions['detective'];
    String? maniacKilled = actions['maniac'];

    if (killed == healed) {
      killed = null;
    }

    await FirebaseFirestore.instance.collection('rooms').doc(roomCode).update({
      'phaseResult': {
        'killed': killed,
        'healed': healed,
        'investigated': investigated,
        'maniacKilled': maniacKilled,
      },
      'gamePhase': 'discussion',
      'nightActions': {},
    });
  }

  static Future<void> calculateVoteResult(
    String roomCode,
    List<Player> players,
    Map<String, dynamic> votes,
  ) async {
    await BotManager.simulateBotVotes(roomCode, players);

    final Map<String, int> voteCounts = {};

    votes.values.forEach((v) {
      voteCounts[v] = (voteCounts[v] ?? 0) + 1;
    });

    String? eliminated;
    int maxVotes = 0;

    voteCounts.forEach((player, count) {
      if (count > maxVotes) {
        maxVotes = count;
        eliminated = player;
      }
    });

    final timestamp = DateTime.now();

    await FirebaseFirestore.instance.collection('rooms').doc(roomCode).update({
      'eliminated': eliminated,
      'voteResult': votes,
      'votes': {},
      'gamePhase': 'result',
    });

    await FirebaseFirestore.instance.collection('history').add({
      'roomCode': roomCode,
      'timestamp': timestamp.toIso8601String(),
      'players': players.map((p) => p.toMap()).toList(),
      'voteResult': votes,
      'eliminated': eliminated,
    });
  }
}
