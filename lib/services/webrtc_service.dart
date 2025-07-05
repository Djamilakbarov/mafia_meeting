// lib/services/webrtc_service.dart

import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../signalling_service.dart';
import 'package:flutter/material.dart'; // Для ChangeNotifier
import 'package:firebase_auth/firebase_auth.dart'; // Для проверки авторизации
import 'package:cloud_firestore/cloud_firestore.dart'; // Для проверки существования комнаты

class WebRTCService extends ChangeNotifier {
  // Больше не синглтон. Provider будет управлять его экземплярами.
  WebRTCService();

  SignalingService? _signalingService;
  String? _currentRoomCode;

  MediaStream? get localStream => _signalingService?.localStream;

  RTCVideoRenderer get localRenderer {
    // Если SignalingService не инициализирован или его рендерер еще не готов, возвращаем пустой рендерер.
    if (_signalingService == null ||
        _signalingService!.localRenderer.textureId == null) {
      return RTCVideoRenderer();
    }
    return _signalingService!.localRenderer;
  }

  Map<String, RTCVideoRenderer> get remoteRenderers =>
      _signalingService?.remoteRenderers ?? {};

  String get localPeerId => _signalingService?.localPeerId ?? '';

  // -------------------- INIT --------------------
  /// Инициализирует WebRTC сервис для заданной комнаты и игрока.
  /// Закрывает предыдущие соединения, если комната или peerId изменились.
  /// Или если WebRTCService используется повторно после dispose.
  // Удалена @override, так как initialize не переопределяет метод ChangeNotifier
  Future<void> initialize(
      String roomCode, String playerName, SignalingService service) async {
    try {
      // Проверка авторизации
      if (FirebaseAuth.instance.currentUser?.uid != playerName) {
        throw Exception(
            'Несанкционированный доступ к WebRTC: UID не совпадает с playerName.');
      }

      // Проверка существования комнаты
      final roomDoc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomCode)
          .get();
      if (!roomDoc.exists) {
        throw Exception('Комната не существует или была закрыта.');
      }

      // Закрываем предыдущие соединения, если они есть и параметры изменились
      // или если SignalingService не был инициализирован ранее
      if (_signalingService != null &&
          (_currentRoomCode != roomCode ||
              _signalingService?.localPeerId != playerName)) {
        await closeWebRTCResources(); // Используем отдельный метод для очистки
      }

      _signalingService = service;
      _currentRoomCode = roomCode; // Устанавливаем текущий код комнаты

      await _signalingService!.initializeWebRTC(roomCode, playerName);

      notifyListeners(); // Уведомляем о первоначальной инициализации состояния WebRTCService
    } catch (e) {
      print("WebRTCService initialization error: $e");
      await closeWebRTCResources(); // Очищаем ресурсы в случае ошибки инициализации
      rethrow; // Перебрасываем исключение, чтобы вызывающий код мог его обработать
    }
  }

  // -------------------- PUBLIC API --------------------
  /// Инициализирует рендереры видеопотоков.
  /// Этот метод теперь в основном делегирует вызов SignalingService.
  Future<void> initRenderers() async {
    await _signalingService?.initRenderers();
    notifyListeners(); // Уведомляем на случай, если состояние рендереров изменилось
  }

  /// Присоединяется к комнате. Вся логика соединения обрабатывается SignalingService.
  Future<void> joinRoom() async {
    await _signalingService?.joinRoom();
    notifyListeners();
  }

  /// Покидает комнату и закрывает все соединения.
  Future<void> leaveRoom() async {
    await _signalingService?.leaveRoom();
    notifyListeners();
  }

  /// Переключает состояние микрофона.
  void toggleAudio() {
    toggleMic(); // Просто переадресация вызова
  }

  /// Переключает состояние микрофона.
  void toggleMic() {
    _signalingService?.toggleMic();
    notifyListeners();
  }

  /// Переключает состояние видеокамеры.
  void toggleVideo() {
    _signalingService?.toggleVideo();
    notifyListeners();
  }

  // -------------------- CLEANUP --------------------
  /// Закрывает все WebRTC соединения и освобождает ресурсы SignalingService.
  /// Этот метод вызывается из dispose() или при переинициализации.
  Future<void> closeWebRTCResources() async {
    try {
      await _signalingService?.close(); // Делегируем закрытие SignalingService
    } catch (e) {
      print("Error closing signaling service: $e");
      // Не перебрасываем здесь, чтобы не блокировать dispose
    } finally {
      _signalingService = null; // Сбрасываем ссылку
      _currentRoomCode = null; // Сбрасываем текущий код комнаты
    }
  }

  /// Метод dispose() для ChangeNotifier.
  /// Вызывается Provider'ом, когда WebRTCService больше не нужен.
  @override
  Future<void> dispose() async {
    // ВАЖНО: super.dispose() должен быть вызван в конце, после всей очистки.
    // Это предотвратит вызовы notifyListeners() на уже диспознутых объектах.
    await closeWebRTCResources(); // Закрываем все WebRTC ресурсы
    super.dispose(); // Вызываем dispose родительского класса
  }
}
