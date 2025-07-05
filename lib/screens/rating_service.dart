import 'package:cloud_firestore/cloud_firestore.dart';

class RatingService {
  static Future<void> updatePlayerRating(String playerName, int change) async {
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(playerName);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);

        if (!snapshot.exists) {
          transaction.set(userRef, {'rating': change});
        } else {
          int currentRating = snapshot.data()?['rating'] ?? 0;
          transaction.update(userRef, {'rating': currentRating + change});
        }
      });
    } catch (e) {
      print("Ошибка при обновлении рейтинга игрока $playerName: $e");
    }
  }

  static Future<void> likePlayer(
      String roomCode, String targetPlayer, String currentPlayer) async {
    if (targetPlayer == currentPlayer) {
      print("Игрок не может лайкнуть сам себя: $targetPlayer");
      return;
    }

    final ratingRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomCode)
        .collection('ratings');

    try {
      await ratingRef.doc(targetPlayer).set({
        'likes': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      print(
          "Ошибка при записи лайка игроку $targetPlayer в комнате $roomCode: $e");
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetPlayer)
          .set({
        'totalLikes': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Ошибка при обновлении общих лайков игрока $targetPlayer: $e");
    }
  }

  static Future<Map<String, int>> loadRatings(String roomCode) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomCode)
          .collection('ratings')
          .get();

      final map = <String, int>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        map[doc.id] = data['likes'] ?? 0;
      }
      return map;
    } catch (e) {
      print("Ошибка при загрузке рейтингов для комнаты $roomCode: $e");
      return {};
    }
  }
}
