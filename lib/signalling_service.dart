// lib/signalling_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class SignalingService extends ChangeNotifier {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  late String roomId;
  late String localPeerId;

  MediaStream? _localStream;
  // ИЗМЕНЕНИЕ: Теперь _localRenderer не final и может быть пересоздан.
  RTCVideoRenderer? _localRenderer;
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};

  MediaStream? get localStream => _localStream;

  // Геттер для localRenderer, который гарантирует, что рендерер инициализирован
  RTCVideoRenderer get localRenderer {
    if (_localRenderer == null) {
      _localRenderer = RTCVideoRenderer();
      // Инициализация нового рендерера должна быть асинхронной, но геттер не может быть async.
      // Поэтому инициализируем его здесь, но без await.
      // Это может вызвать небольшую задержку, но лучше, чем LateInitializationError.
      _localRenderer!.initialize();
    }
    return _localRenderer!;
  }

  Map<String, RTCVideoRenderer> get remoteRenderers => _remoteRenderers;

  DatabaseReference? _roomRef;

  Function(MediaStream stream, String peerId)? _onAddRemoteStream;
  Function(String peerId)? _onRemoveRemoteStream;

  set onAddRemoteStream(Function(MediaStream stream, String peerId)? callback) {
    _onAddRemoteStream = callback;
  }

  set onRemoveRemoteStream(Function(String peerId)? callback) {
    _onRemoveRemoteStream = callback;
  }

  final Map<String, StreamSubscription<DatabaseEvent>> _offerListeners = {};
  final Map<String, StreamSubscription<DatabaseEvent>> _answerListeners = {};
  final Map<String, StreamSubscription<DatabaseEvent>> _iceCandidateListeners =
      {};
  StreamSubscription<QuerySnapshot>? _peerDiscoverySubscription;

  SignalingService();

  Future<void> initializeWebRTC(String newRoomId, String newLocalPeerId) async {
    // Всегда вызываем close() перед новой инициализацией, чтобы гарантировать полную очистку.
    await close();

    roomId = newRoomId;
    localPeerId = newLocalPeerId;
    _roomRef = _database.ref('rooms/$roomId');

    // Инициализируем или переинициализируем _localRenderer здесь
    if (_localRenderer == null) {
      _localRenderer = RTCVideoRenderer();
    }
    // Если рендерер был диспознут, его нужно инициализировать снова
    if (_localRenderer!.textureId == null) {
      await _localRenderer!.initialize();
    }

    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user'},
      });
      _localStream = stream;
      _localRenderer!.srcObject =
          stream; // Теперь _localRenderer гарантированно инициализирован
      notifyListeners(); // Уведомляем об обновлении localStream и localRenderer
    } catch (e) {
      print("SignalingService: MediaStream error: $e");
      _localStream = null;
      if (_localRenderer != null) {
        _localRenderer!.srcObject = null; // Очищаем srcObject при ошибке
        await _localRenderer!
            .dispose(); // Диспозим рендерер, если не удалось получить поток
        _localRenderer =
            null; // Обнуляем ссылку, чтобы он был пересоздан при следующей попытке
      }
      notifyListeners(); // Уведомляем об изменении состояния (например, камера недоступна)
      rethrow; // Перебрасываем ошибку, чтобы WebRTCService мог ее поймать
    }

    // Сохраняем информацию о присутствии peer в Firestore для обнаружения
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('video_peers')
        .doc(localPeerId)
        .set({
      'playerName': localPeerId,
      'timestamp': FieldValue.serverTimestamp(),
      'isMicOn': _localStream?.getAudioTracks().first.enabled ?? true,
      'isCamOn': _localStream?.getVideoTracks().first.enabled ?? true,
    }, SetOptions(merge: true));

    _listenForSignalingMessages();
    _listenForPeerDiscovery();
  }

  Future<void> initRenderers() async {
    // Этот метод теперь менее критичен, так как инициализация _localRenderer
    // происходит в initializeWebRTC. Он может использоваться для перерисовки
    // удаленных рендереров.
    if (_localRenderer == null) {
      _localRenderer = RTCVideoRenderer();
      await _localRenderer!.initialize();
    } else if (_localRenderer!.textureId == null) {
      await _localRenderer!.initialize();
    }
    notifyListeners();
  }

  Future<void> joinRoom() async {
    print(
        "SignalingService: joinRoom called. Peer discovery handles connections.");
    // notifyListeners(); // Не нужен здесь, так как joinRoom не меняет видимое состояние SignalingService
  }

  Future<void> leaveRoom() async {
    await close();
    print("SignalingService: leaveRoom called.");
    // notifyListeners(); // Не нужен здесь, так как close() уже вызван
  }

  void _listenForSignalingMessages() {
    _offerListeners.values.forEach((s) => s.cancel());
    _answerListeners.values.forEach((s) => s.cancel());
    _iceCandidateListeners.values.forEach((s) => s.cancel());
    _offerListeners.clear();
    _answerListeners.clear();
    _iceCandidateListeners.clear();

    _offerListeners[localPeerId] = _roomRef!
        .child('peers')
        .child(localPeerId)
        .child('offer')
        .onValue
        .listen((event) async {
      final data = event.snapshot.value as Map?;
      if (data != null && data['senderId'] != localPeerId) {
        final offer = RTCSessionDescription(data['sdp'], data['type']);
        await _onRemoteOffer(offer, data['senderId']);
        await event.snapshot.ref.remove();
      }
    });

    _answerListeners[localPeerId] = _roomRef!
        .child('peers')
        .child(localPeerId)
        .child('answer')
        .onValue
        .listen((event) async {
      final data = event.snapshot.value as Map?;
      if (data != null && data['senderId'] != localPeerId) {
        final answer = RTCSessionDescription(data['sdp'], data['type']);
        await _onRemoteAnswer(answer, data['senderId']);
        await event.snapshot.ref.remove();
      }
    });

    _iceCandidateListeners[localPeerId] = _roomRef!
        .child('peers')
        .child(localPeerId)
        .child('iceCandidates')
        .onChildAdded
        .listen((event) async {
      final data = event.snapshot.value as Map?;
      if (data != null && data['senderId'] != localPeerId) {
        final candidate = RTCIceCandidate(
            data['candidate'], data['sdpMid'], data['sdpMLineIndex']);
        _peerConnections[data['senderId']]?.addCandidate(candidate);
        await event.snapshot.ref.remove();
      }
    });
  }

  void _listenForPeerDiscovery() {
    _peerDiscoverySubscription?.cancel();
    _peerDiscoverySubscription = FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('video_peers')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        final remotePeerId = change.doc.id;
        if (remotePeerId == localPeerId) continue;

        if (change.type == DocumentChangeType.added) {
          _onNewPeer(remotePeerId);
        } else if (change.type == DocumentChangeType.removed) {
          _onPeerLeft(remotePeerId);
        }
      }
    }, onError: (e) => print("Peer discovery listener error: $e"));
  }

  Future<void> _onNewPeer(String remotePeerId) async {
    if (_peerConnections.containsKey(remotePeerId)) {
      print("Соединение с $remotePeerId уже существует.");
      return;
    }

    final pc = await _createPeerConnection(remotePeerId);
    _peerConnections[remotePeerId] = pc;

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        pc.addTrack(track, _localStream!);
      }
    }

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    await sendOffer(offer, localPeerId, targetPeerId: remotePeerId);
  }

  Future<RTCPeerConnection> _createPeerConnection(String remotePeerId) async {
    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    });

    pc.onIceCandidate = (candidate) {
      sendCandidate(candidate, localPeerId, targetPeerId: remotePeerId);
    };

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        final stream = event.streams[0];
        final renderer = _remoteRenderers[remotePeerId] ?? RTCVideoRenderer();
        if (renderer.textureId == null) {
          renderer.initialize().then((_) {
            renderer.srcObject = stream;
            _remoteRenderers[remotePeerId] = renderer;
            _onAddRemoteStream?.call(stream, remotePeerId);
            notifyListeners(); // Уведомляем слушателей SignalingService
          });
        } else {
          renderer.srcObject = stream;
          _remoteRenderers[remotePeerId] = renderer;
          _onAddRemoteStream?.call(stream, remotePeerId);
          notifyListeners(); // Уведомляем слушателей SignalingService
        }
      }
    };

    return pc;
  }

  Future<void> sendOffer(RTCSessionDescription offer, String senderId,
      {required String targetPeerId}) async {
    await _roomRef!.child('peers').child(targetPeerId).child('offer').set({
      'sdp': offer.sdp,
      'type': offer.type,
      'senderId': senderId,
      'timestamp': ServerValue.timestamp,
    });
  }

  Future<void> sendAnswer(RTCSessionDescription answer, String senderId,
      {required String targetPeerId}) async {
    await _roomRef!.child('peers').child(targetPeerId).child('answer').set({
      'sdp': answer.sdp,
      'type': answer.type,
      'senderId': senderId,
      'timestamp': ServerValue.timestamp,
    });
  }

  Future<void> sendCandidate(RTCIceCandidate candidate, String senderId,
      {required String targetPeerId}) async {
    await _roomRef!
        .child('peers')
        .child(targetPeerId)
        .child('iceCandidates')
        .push()
        .set({
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
      'senderId': senderId,
      'timestamp': ServerValue.timestamp,
    });
  }

  Future<void> _onRemoteOffer(
      RTCSessionDescription offer, String remotePeerId) async {
    final pc = _peerConnections[remotePeerId] ??
        await _createPeerConnection(remotePeerId);
    _peerConnections[remotePeerId] = pc;

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        pc.addTrack(track, _localStream!);
      }
    }

    await pc.setRemoteDescription(offer);
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    await sendAnswer(answer, localPeerId, targetPeerId: remotePeerId);
  }

  Future<void> _onRemoteAnswer(
      RTCSessionDescription answer, String remotePeerId) async {
    await _peerConnections[remotePeerId]?.setRemoteDescription(answer);
  }

  void _onPeerLeft(String remotePeerId) {
    _remoteRenderers[remotePeerId]?.srcObject = null;
    _remoteRenderers[remotePeerId]?.dispose();
    _remoteRenderers.remove(remotePeerId);

    _peerConnections[remotePeerId]?.close();
    _peerConnections.remove(remotePeerId);

    _onRemoveRemoteStream?.call(remotePeerId);
    notifyListeners(); // Уведомляем слушателей SignalingService
  }

  void toggleMic() {
    final track = _localStream?.getAudioTracks().first;
    if (track != null) {
      track.enabled = !track.enabled;
      FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('video_peers')
          .doc(localPeerId)
          .update({
        'isMicOn': track.enabled,
      }).catchError((e) => print("Ошибка обновления статуса микрофона: $e"));
    }
    notifyListeners();
  }

  void toggleVideo() {
    final track = _localStream?.getVideoTracks().first;
    if (track != null) {
      track.enabled = !track.enabled;
      FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('video_peers')
          .doc(localPeerId)
          .update({
        'isCamOn': track.enabled,
      }).catchError((e) => print("Ошибка обновления статуса камеры: $e"));
    }
    notifyListeners();
  }

  Future<void> close() async {
    _peerDiscoverySubscription?.cancel();
    _offerListeners.values.forEach((s) => s.cancel());
    _answerListeners.values.forEach((s) => s.cancel());
    _iceCandidateListeners.values.forEach((s) => s.cancel());
    _offerListeners.clear();
    _answerListeners.clear();
    _iceCandidateListeners.clear();

    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _localStream = null;

    // ИЗМЕНЕНИЕ: Безопасно диспозим и обнуляем _localRenderer
    if (_localRenderer != null) {
      if (_localRenderer!.textureId != null) {
        _localRenderer!.srcObject = null;
        await _localRenderer!.dispose();
      }
      _localRenderer = null; // Обнуляем ссылку
    }

    for (var renderer in _remoteRenderers.values) {
      renderer.srcObject = null;
      await renderer.dispose();
    }
    _remoteRenderers.clear();

    for (var pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();

    // Удаляем информацию о peer из Firestore
    // Проверяем _roomRef, чтобы убедиться, что roomId и localPeerId были инициализированы.
    if (_roomRef != null && roomId.isNotEmpty && localPeerId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(roomId)
            .collection('video_peers')
            .doc(localPeerId)
            .delete();
      } catch (e) {
        print("Ошибка при удалении peer из Firestore: $e");
      }
    }

    _roomRef = null;
    // notifyListeners(); // Эту строку мы удалили, чтобы избежать setState() during build
  }

  @override
  void dispose() {
    close(); // Вызываем close для очистки ресурсов
    super.dispose();
  }
}
