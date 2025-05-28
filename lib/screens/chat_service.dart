import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final bannedWords = ['fuck', 'shit', 'бляд', 'сука', 'хуй', 'пизд', 'еба'];

  static bool _containsBannedWords(String message) {
    final lower = message.toLowerCase();
    return bannedWords.any((word) => lower.contains(word));
  }

  static Stream<QuerySnapshot> getChatStream(String roomCode) {
    return FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomCode)
        .collection('chat')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  static Future<bool> sendMessage(
      String roomCode, String playerName, String message) async {
    if (_containsBannedWords(message)) return false;
    if (message.trim().isEmpty) return false;

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomCode)
        .collection('chat')
        .add({
      'sender': playerName,
      'message': message.trim(),
      'timestamp': Timestamp.now(),
    });
    return true;
  }
}
