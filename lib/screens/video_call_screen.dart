import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class VideoCallScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;

  const VideoCallScreen(
      {super.key, required this.roomCode, required this.playerName});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool _isMuted = false;
  bool _isVideoOff = false;
  MediaStream? _localStream;
  final _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  final Map<String, RTCPeerConnection> _peerConnections = {};
  MediaStream? _localStream;
  final _uuid = const Uuid();
  late String _id;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _initConnection();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    _id = _uuid.v4();
  }

  Future<void> _initConnection() async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'},
    });
    setState(() {
      _localStream = stream;
      _localRenderer.srcObject = stream;
    });

    FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .collection('video')
        .doc(_id)
        .set({
      'name': widget.playerName,
      'timestamp': DateTime.now().millisecondsSinceEpoch
    });
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _localStream?.dispose();
    for (final renderer in _remoteRenderers.values) {
      renderer.dispose();
    }
    for (final pc in _peerConnections.values) {
      pc.close();
    }
    FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .collection('video')
        .doc(_id)
        .delete();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Видеозвонок')),
      body: Column(
        children: [
          Expanded(
            child: RTCVideoView(_localRenderer, mirror: true),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _remoteRenderers.values
                  .map((renderer) => AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          color: Colors.black,
                          child: RTCVideoView(renderer),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}