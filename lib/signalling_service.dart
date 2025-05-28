import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class SignalingService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final String roomId;
  final RTCPeerConnection _peerConnection;
  final RTCVideoRenderer remoteRenderer;

  SignalingService({
    required this.roomId,
    required RTCPeerConnection peerConnection,
    required this.remoteRenderer,
  }) : _peerConnection = peerConnection {
    _listenForRemoteSDP();
    _listenForICECandidates();
  }

  Future<void> createOffer() async {
    RTCSessionDescription offer = await _peerConnection.createOffer();
    await _peerConnection.setLocalDescription(offer);
    await _database.ref('rooms/$roomId/offer').set({
      'sdp': offer.sdp,
      'type': offer.type,
    });
  }

  Future<void> setAnswer(RTCSessionDescription answer) async {
    await _peerConnection.setRemoteDescription(answer);
  }

  void _listenForRemoteSDP() {
    _database.ref('rooms/$roomId/answer').onValue.listen((event) async {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        final answer = RTCSessionDescription(data['sdp'], data['type']);
        await _peerConnection.setRemoteDescription(answer);
      }
    });
  }

  void _listenForICECandidates() {
    _database.ref('rooms/$roomId/ice').onChildAdded.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        final candidate = RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        );
        _peerConnection.addCandidate(candidate);
      }
    });
  }

  Future<void> sendCandidate(RTCIceCandidate candidate) async {
    await _database.ref('rooms/$roomId/ice').push().set({
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    });
  }

  Future<void> close() async {
    await _peerConnection.close();
    await _database.ref('rooms/$roomId').remove();
  }
}
