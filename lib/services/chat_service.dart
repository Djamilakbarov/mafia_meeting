import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mafia_meeting/main.dart';

class ChatService {
  static final List<String> _bannedWords = [
    'fuck',
    'shit',
    'бляд',
    'сука',
    'хуй',
    'пизд',
    'еба',
  ];

  static final TextEditingController messageController =
      TextEditingController();

  static bool containsBannedWords(String message) {
    final lower = message.toLowerCase();
    return _bannedWords.any(
      (word) => lower.contains(word),
    );
  }

  static Stream<QuerySnapshot> getChatStream(String roomCode) {
    return FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomCode)
        .collection('chat')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  static Future<void> sendMessage(
    String roomCode,
    String playerName,
    String message,
  ) async {
    BuildContext? context = NavigatorService.navigatorKey.currentContext;

    if (containsBannedWords(message)) {
      if (context != null) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.messageBlocked)),
        );
      }
      return;
    }

    if (message.trim().isEmpty) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomCode)
          .collection('chat')
          .add({
        'sender': playerName,
        'message': message.trim(),
        'timestamp': Timestamp.now(),
      });
      messageController.clear();
    } catch (e) {
      print("Ошибка при отправке сообщения чата: $e");
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки сообщения: $e')),
        );
      }
    }
  }
}
