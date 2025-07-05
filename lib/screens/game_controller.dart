import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/player_model.dart';

class GameController {
  static Future<void> calculateNightResult(
    String roomCode,
    List<Player> players,
    Map<String, dynamic> actions,
  ) async {
    String? killed = actions['mafia'];
    String? healed = actions['doctor'];
    String? investigated = actions['detective'];
    String? maniacKilled = actions['maniac'];

    if (killed == healed) {
      killed = null;
    }

    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomCode)
          .update({
        'phaseResult': {
          'killed': killed,
          'healed': healed,
          'investigated': investigated,
          'maniacKilled': maniacKilled,
        },
        'gamePhase': 'discussion',
        'nightActions': {},
      });
    } catch (e) {
      print("Ошибка при обновлении ночных результатов комнаты ($roomCode): $e");
    }
  }

  static Future<void> calculateVoteResult(
    String roomCode,
    List<Player> players,
    Map<String, dynamic> votes,
  ) async {
    final Map<String, int> voteCounts = {};

    votes.values.forEach((v) {
      if (v != null && v is String) {
        voteCounts[v] = (voteCounts[v] ?? 0) + 1;
      }
    });

    String? eliminated;
    int maxVotes = 0;
    List<String> playersWithMaxVotes = [];

    voteCounts.forEach((player, count) {
      if (count > maxVotes) {
        maxVotes = count;
        eliminated = player;
        playersWithMaxVotes = [player];
      } else if (count == maxVotes) {
        playersWithMaxVotes.add(player);
      }
    });

    if (playersWithMaxVotes.length > 1 || voteCounts.isEmpty) {
      eliminated = null;
    } else {
      eliminated = playersWithMaxVotes.first;
    }

    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomCode)
          .update({
        'eliminated': eliminated,
        'voteResult': votes,
        'votes': {},
        'gamePhase': 'result',
      });
    } catch (e) {
      print(
          "Ошибка при обновлении результатов голосования комнаты ($roomCode): $e");
    }

    try {
      await FirebaseFirestore.instance.collection('history').add({
        'roomCode': roomCode,
        'timestamp': FieldValue.serverTimestamp(),
        'players': players.map((p) => p.toMap()).toList(),
        'voteResult': voteCounts,
        'eliminated': eliminated,
      });
    } catch (e) {
      print("Ошибка при добавлении истории игры ($roomCode): $e");
    }
  }
}
