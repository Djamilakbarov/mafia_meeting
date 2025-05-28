import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/player_model.dart';

class BotManager {
  static Future<void> simulateNightActions(
      String roomCode, List<Player> players) async {
    final roomRef =
        FirebaseFirestore.instance.collection('rooms').doc(roomCode);
    final data = (await roomRef.get()).data();
    if (data == null) return;
    final actions = Map<String, dynamic>.from(data['nightActions'] ?? {});
    final rand = Random();

    for (final p in players.where((p) => p.isAlive && p.isBot)) {
      if (actions.containsKey(p.role.name)) continue;

      final targets = players
          .where((t) => t.isAlive && t.name != p.name && !t.isBot)
          .toList();
      if (targets.isEmpty) continue;

      final target = targets[rand.nextInt(targets.length)];
      actions[p.role.name] = target.name;
    }

    await roomRef.set({'nightActions': actions}, SetOptions(merge: true));
  }

  static Future<void> simulateBotVotes(
      String roomCode, List<Player> players) async {
    final roomRef =
        FirebaseFirestore.instance.collection('rooms').doc(roomCode);
    final data = (await roomRef.get()).data();
    if (data == null) return;
    final voteMap = Map<String, dynamic>.from(data['votes'] ?? {});
    final rand = Random();

    for (final p in players.where((p) => p.isAlive && p.isBot)) {
      if (voteMap.containsKey(p.name)) continue;

      final targets = players
          .where((t) => t.isAlive && t.name != p.name && !t.isBot)
          .toList();
      if (targets.isEmpty) continue;

      final target = targets[rand.nextInt(targets.length)];
      voteMap[p.name] = target.name;
    }

    await roomRef.set({'votes': voteMap}, SetOptions(merge: true));
  }
}