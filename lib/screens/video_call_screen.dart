import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../services/webrtc_service.dart';
import '../signalling_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class VideoCallScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;

  const VideoCallScreen({
    super.key,
    required this.roomCode,
    required this.playerName,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late WebRTCService _webRTCService;

  @override
  void initState() {
    super.initState();
    _webRTCService = WebRTCService();
    final signalingService =
        Provider.of<SignalingService>(context, listen: false);

    _webRTCService.initialize(
      widget.roomCode,
      widget.playerName,
      signalingService,
    );
  }

  @override
  void dispose() {
    _webRTCService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return ChangeNotifierProvider.value(
      value: _webRTCService,
      child: Consumer<WebRTCService>(
        builder: (context, service, _) {
          return Scaffold(
            appBar: AppBar(
              title: Text(loc.videoCallTitle),
              actions: [
                IconButton(
                  icon: Icon(
                    service.localStream?.getAudioTracks().first.enabled ?? true
                        ? Icons.mic
                        : Icons.mic_off,
                  ),
                  onPressed: service.toggleMic,
                ),
                IconButton(
                  icon: Icon(
                    service.localStream?.getVideoTracks().first.enabled ?? true
                        ? Icons.videocam
                        : Icons.videocam_off,
                  ),
                  onPressed: service.toggleVideo,
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: Container(
                    color: Colors.black,
                    child: service.localRenderer.srcObject != null &&
                            service.localRenderer.textureId != null
                        ? RTCVideoView(service.localRenderer, mirror: true)
                        : Center(child: Text(loc.cameraLoading)),
                  ),
                ),
                const Divider(),
                SizedBox(
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: service.remoteRenderers.entries.map((entry) {
                      return AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          color: Colors.black,
                          child: RTCVideoView(entry.value),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
