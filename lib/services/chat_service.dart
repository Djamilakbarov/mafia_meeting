// lib/services/chat_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Добавлен импорт для TextEditingController

class ChatService {
  static final TextEditingController messageController = TextEditingController(); // ДОБАВЛЕНО ЭТО

  static Stream<QuerySnapshot> getChatStream(String roomCode) {
    return FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomCode)
        .collection('chat')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  static Future<void> sendMessage(
      String roomCode, String playerName, String message) async {
    if (message.trim().isEmpty) return;

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomCode)
        .collection('chat')
        .add({
      'sender': playerName,
      'message': message.trim(),
      'timestamp': Timestamp.now(),
    });
    // Очищаем контроллер после отправки
    messageController.clear(); // ДОБАВЛЕНО ЭТО
  }
}