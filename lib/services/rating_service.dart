// lib/services/rating_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class RatingService {
  // Этот метод теперь используется для общего обновления рейтинга игрока
  static Future<void> updatePlayerRating(String playerName, int change) async {
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(playerName);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);

      if (!snapshot.exists) {
        // Если пользователя еще нет, создаем его с начальным рейтингом
        transaction.set(userRef, {'rating': change});
      } else {
        // Если пользователь есть, обновляем рейтинг
        int currentRating = snapshot.data()?['rating'] ?? 0;
        transaction.update(userRef, {'rating': currentRating + change});
      }
    });
  }

  // Метод likePlayer без изменений, он обрабатывает лайки в рамках комнаты и общие лайки пользователя
  static Future<void> likePlayer(
      String roomCode, String targetPlayer, String currentPlayer) async {
    if (targetPlayer == currentPlayer) return;

    final ratingRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomCode)
        .collection('ratings');

    await ratingRef.doc(targetPlayer).set({
      'likes': FieldValue.increment(1),
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('users').doc(targetPlayer).set({
      'totalLikes': FieldValue.increment(1),
      'gamesPlayed': FieldValue.increment(
          1), // Возможно, здесь должен быть gamesPlayed, а не wins/losses
    }, SetOptions(merge: true));
  }

  static Future<Map<String, int>> loadRatings(String roomCode) async {
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
  }
}
