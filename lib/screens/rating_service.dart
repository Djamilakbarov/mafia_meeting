
import 'package:cloud_firestore/cloud_firestore.dart';

class RatingService {
  static Future<void> likePlayer(String roomCode, String targetPlayer, String currentPlayer) async {
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
      'gamesPlayed': FieldValue.increment(1),
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
