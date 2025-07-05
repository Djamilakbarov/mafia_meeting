import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'game_screen.dart';
import 'lobby_screen.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/webrtc_service.dart';
import 'package:provider/provider.dart';
import '../signalling_service.dart';
import '../models/player_model.dart';
import '../models/role_enum.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WaitingRoomScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;
  final String currentUserId;
  final Future<void> Function(bool) toggleTheme;
  final bool isDarkMode;

  const WaitingRoomScreen({
    super.key,
    required this.roomCode,
    required this.playerName,
    required this.currentUserId,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  int _discussionTime = 120;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _roomStream;

  late WebRTCService _webrtcService;

  Map<String, bool> playerMicStatus = {};
  Map<String, bool> playerCamStatus = {};

  // Состояние для анимации кнопок
  bool _isMicButtonPressed = false;
  bool _isCameraButtonPressed = false;
  bool _isStartGameButtonPressed = false;
  bool _isLeaveRoomButtonPressed = false;

  @override
  void initState() {
    super.initState();
    _roomStream = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .snapshots();
    WakelockPlus.enable();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadInitialRoomSettings();

    _webrtcService = Provider.of<WebRTCService>(context, listen: false);
    final signalingService =
        Provider.of<SignalingService>(context, listen: false);

    _initializeWebRTC(_webrtcService, signalingService, widget.currentUserId);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _loadInitialRoomSettings() async {
    final loc = AppLocalizations.of(context)!;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomCode)
          .get();
      if (mounted && doc.exists && doc.data() != null) {
        final roomSettings = doc.data()!['roomSettings'];
        if (roomSettings is Map<String, dynamic> &&
            roomSettings.containsKey('discussionDuration')) {
          setState(() {
            _discussionTime = roomSettings['discussionDuration'];
          });
        }
      }
    } catch (e) {
      print("Ошибка загрузки начальных настроек комнаты: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.loadRoomSettingsError)),
        );
      }
    }
  }

  Future<void> _initializeWebRTC(WebRTCService webRTCService,
      SignalingService signalingService, String userId) async {
    final loc = AppLocalizations.of(context)!;
    try {
      await webRTCService.initialize(
        widget.roomCode,
        userId,
        signalingService,
      );
    } catch (e) {
      print("Ошибка инициализации WebRTC в WaitingRoomScreen: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.cameraError)),
        );
      }
    }
  }

  void _toggleMic() {
    _webrtcService.toggleMic();
  }

  void _toggleVideo() {
    _webrtcService.toggleVideo();
  }

  void _startGame(List<String> playerIds) async {
    final loc = AppLocalizations.of(context)!;

    if (playerIds.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.notEnoughPlayers)),
      );
      return;
    }

    final roomSnapshot = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .get();

    if (!roomSnapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.invalidRoomCode)),
      );
      return;
    }

    final updatedRoomDoc = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .get();

    final updatedPlayersData = updatedRoomDoc.data()?['players'];
    List<Player> currentPlayersInRoom = [];
    if (updatedPlayersData is List) {
      currentPlayersInRoom = updatedPlayersData
          .map((p) => Player.fromMap(p as Map<String, dynamic>))
          .toList();
    }

    if (currentPlayersInRoom.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.notEnoughPlayers)),
      );
      return;
    }

    List<Role> roles = _generateRoles(currentPlayersInRoom.length);
    roles.shuffle();

    List<Map<String, dynamic>> assignedPlayers = [];
    for (int i = 0; i < currentPlayersInRoom.length; i++) {
      final updatedPlayer = currentPlayersInRoom[i].copyWith(
        role: roles[i],
        isAlive: true,
        likesReceived: 0,
      );
      assignedPlayers.add(updatedPlayer.toMap());
    }

    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomCode)
          .update({
        'started': true,
        'gamePhase': 'discussion',
        'players': assignedPlayers,
        'roomSettings.discussionDuration': _discussionTime,
        'nightActions': {},
        'votes': {},
      });
    } catch (e) {
      print("Ошибка при обновлении комнаты для старта игры: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.startGameError)),
      );
    }
  }

  List<Role> _generateRoles(int count) {
    List<Role> result = [];

    if (count >= 4) {
      result.add(Role.mafia);
    }

    if (count >= 5) {
      result.add(Role.doctor);
    }
    if (count >= 6) {
      result.add(Role.detective);
    }
    if (count >= 7) {
      result.add(Role.maniac);
    }
    if (count >= 8) {
      result.add(Role.mafia);
    }
    if (count >= 11) {
      if (result.where((role) => role == Role.mafia).length < 3) {
        result.add(Role.mafia);
      }
    }

    while (result.length < count) {
      result.add(Role.villager);
    }

    result.shuffle();
    return result;
  }

  void _leaveRoom() async {
    final loc = AppLocalizations.of(context)!;
    try {
      final docRef =
          FirebaseFirestore.instance.collection('rooms').doc(widget.roomCode);
      final doc = await docRef.get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final rawPlayers = data['players'];

        List<Map<String, dynamic>> playersInRoom = [];
        if (rawPlayers is List) {
          playersInRoom = rawPlayers
              .map((p) => p is Map<String, dynamic> ? p : null)
              .whereType<Map<String, dynamic>>()
              .toList();
        }

        final newPlayers = playersInRoom
            .where((p) => p['id'] != widget.currentUserId)
            .toList();
        final isHost = data['host'] == widget.playerName;

        if (newPlayers.isEmpty) {
          await docRef.delete();
        } else {
          await docRef.update({'players': newPlayers});
          if (isHost) {
            await docRef.update({'host': newPlayers.first['name']});
          }
        }
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomCode)
            .collection('video_peers')
            .doc(widget.currentUserId)
            .delete();
      }
    } catch (e) {
      print("Ошибка при выходе из комнаты: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.leaveRoomError}: $e')),
      );
    } finally {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (context) => LobbyScreen(
                  currentUserId: FirebaseAuth.instance.currentUser!.uid,
                  playerName: widget.playerName,
                  toggleTheme: widget.toggleTheme,
                  isDarkMode: widget.isDarkMode,
                )),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.roomPlayers),
        backgroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.isDarkMode
                ? [Colors.grey[900]!, Colors.blueGrey[800]!]
                : [Colors.blueGrey[100]!, Colors.blueGrey[300]!],
          ),
        ),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _roomStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                  child: Text("${loc.error}: ${snapshot.error}",
                      style: TextStyle(color: Colors.white)));
            }
            if (!snapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white));
            }
            if (!snapshot.data!.exists) {
              return Center(
                  child: Text(loc.invalidRoomCode,
                      style: TextStyle(color: Colors.white)));
            }

            final roomData = snapshot.data!.data()!;
            final rawPlayers = roomData['players'];
            final players = (rawPlayers as List)
                .map(
                  (p) => Player.fromMap(p as Map<String, dynamic>),
                )
                .whereType<Player>()
                .toList();

            final host = roomData['host'];
            final started = roomData['started'] ?? false;

            if (started) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameScreen(
                      roomCode: widget.roomCode,
                      playerName: widget.playerName,
                      currentUserId: widget.currentUserId,
                      toggleTheme: widget.toggleTheme,
                      isDarkMode: widget.isDarkMode,
                    ),
                  ),
                );
              });
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "${loc.roomCode}: ${widget.roomCode}",
                    style: const TextStyle(
                      fontFamily: 'Geometria',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Video Section - Using Consumer to listen to WebRTCService changes
                Consumer<WebRTCService>(
                  builder: (context, webRTCService, child) {
                    final bool isMicOn = webRTCService.localStream
                            ?.getAudioTracks()
                            .first
                            .enabled ??
                        false;
                    final bool isCamOn = webRTCService.localStream
                            ?.getVideoTracks()
                            .first
                            .enabled ??
                        false;

                    return Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          // Local Video (Larger)
                          Expanded(
                            child: Card(
                              margin: const EdgeInsets.all(8),
                              elevation: 8,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15)),
                              clipBehavior: Clip.antiAlias,
                              child: Container(
                                color: Colors.black,
                                child: (webRTCService.localStream != null &&
                                        webRTCService.localRenderer.textureId !=
                                            null)
                                    ? RTCVideoView(webRTCService.localRenderer,
                                        mirror: true,
                                        objectFit: RTCVideoViewObjectFit
                                            .RTCVideoViewObjectFitCover)
                                    : Center(
                                        child: Text(loc.cameraLoading,
                                            style: TextStyle(
                                                color: Colors.white70))),
                              ),
                            ),
                          ),
                          // Remote Videos (Horizontal Scroll)
                          if (webRTCService.remoteRenderers.isNotEmpty)
                            SizedBox(
                              height: 100, // Reduced height for remote videos
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: webRTCService.remoteRenderers.length,
                                itemBuilder: (context, index) {
                                  final peerId = webRTCService
                                      .remoteRenderers.keys
                                      .elementAt(index);
                                  final renderer =
                                      webRTCService.remoteRenderers[peerId]!;

                                  final playerFromList = players.firstWhere(
                                    (p) => p.id == peerId,
                                    orElse: () => Player(
                                        id: peerId,
                                        name: 'Unknown',
                                        role: Role.villager),
                                  );

                                  // Эти статусы должны обновляться через SignalingService
                                  // или напрямую из WebRTCService (если они там доступны)
                                  final bool micStatus =
                                      playerMicStatus[peerId] ?? true;
                                  final bool camStatus =
                                      playerCamStatus[peerId] ?? true;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4.0),
                                    child: Card(
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      clipBehavior: Clip.antiAlias,
                                      child: Container(
                                        width:
                                            100, // Fixed width for remote video cards
                                        color: Colors.black,
                                        child: Stack(
                                          children: [
                                            RTCVideoView(renderer,
                                                objectFit: RTCVideoViewObjectFit
                                                    .RTCVideoViewObjectFitCover),
                                            if (!playerFromList.isAlive)
                                              Positioned.fill(
                                                child: Container(
                                                  color: Colors.black54,
                                                  child: Center(
                                                    child: Text(loc.eliminated,
                                                        style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 14)),
                                                  ),
                                                ),
                                              ),
                                            Positioned(
                                              bottom: 4,
                                              left: 4,
                                              right: 4,
                                              child: Text(
                                                playerFromList.name,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    shadows: [
                                                      Shadow(
                                                          blurRadius: 2,
                                                          color: Colors.black)
                                                    ]),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (!micStatus &&
                                                playerFromList.isAlive)
                                              const Positioned(
                                                top: 4,
                                                left: 4,
                                                child: Icon(Icons.mic_off,
                                                    color: Colors.redAccent,
                                                    size: 16),
                                              ),
                                            if (!camStatus &&
                                                playerFromList.isAlive)
                                              const Positioned(
                                                top: 4,
                                                right: 4,
                                                child: Icon(Icons.videocam_off,
                                                    color: Colors.redAccent,
                                                    size: 16),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          // Mic/Cam Controls
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Кнопка микрофона
                                GestureDetector(
                                  onTapDown: (_) => setState(
                                      () => _isMicButtonPressed = true),
                                  onTapUp: (_) => setState(
                                      () => _isMicButtonPressed = false),
                                  onTapCancel: () => setState(
                                      () => _isMicButtonPressed = false),
                                  onTap: _toggleMic,
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                      begin: 1.0,
                                      end: _isMicButtonPressed ? 0.95 : 1.0,
                                    ),
                                    duration: const Duration(milliseconds: 100),
                                    builder: (context, scale, child) {
                                      return Transform.scale(
                                        scale: scale,
                                        child: ElevatedButton.icon(
                                          onPressed: null,
                                          icon: Icon(isMicOn
                                              ? Icons.mic
                                              : Icons.mic_off),
                                          label: Flexible(
                                            // <-- Изменение здесь
                                            child: Text(
                                              isMicOn ? loc.mute : loc.unmute,
                                              textAlign: TextAlign.center,
                                              maxLines:
                                                  2, // <-- Разрешаем 2 строки
                                              overflow: TextOverflow
                                                  .ellipsis, // <-- Добавляем многоточие если не помещается
                                              style: TextStyle(
                                                  fontSize:
                                                      12), // <-- Уменьшаем размер шрифта
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isMicOn
                                                ? Colors.green
                                                : Colors.red,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            fixedSize: Size(150,
                                                50), // <-- Возможно, зафиксировать размер кнопки
                                            textStyle: TextStyle(
                                                fontSize:
                                                    12), // <-- Уменьшаем общий размер шрифта кнопки
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 20),
                                // Кнопка камеры
                                GestureDetector(
                                  onTapDown: (_) => setState(
                                      () => _isCameraButtonPressed = true),
                                  onTapUp: (_) => setState(
                                      () => _isCameraButtonPressed = false),
                                  onTapCancel: () => setState(
                                      () => _isCameraButtonPressed = false),
                                  onTap: _toggleVideo,
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                      begin: 1.0,
                                      end: _isCameraButtonPressed ? 0.95 : 1.0,
                                    ),
                                    duration: const Duration(milliseconds: 100),
                                    builder: (context, scale, child) {
                                      return Transform.scale(
                                        scale: scale,
                                        child: ElevatedButton.icon(
                                          onPressed: null,
                                          icon: Icon(isCamOn
                                              ? Icons.videocam
                                              : Icons.videocam_off),
                                          label: Flexible(
                                            // <-- Изменение здесь
                                            child: Text(
                                              isCamOn
                                                  ? loc.hideVideo
                                                  : loc.showVideo,
                                              textAlign: TextAlign.center,
                                              maxLines:
                                                  2, // <-- Разрешаем 2 строки
                                              overflow: TextOverflow
                                                  .ellipsis, // <-- Добавляем многоточие
                                              style: TextStyle(
                                                  fontSize:
                                                      12), // <-- Уменьшаем размер шрифта
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isCamOn
                                                ? Colors.green
                                                : Colors.red,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            fixedSize: Size(150,
                                                50), // <-- Возможно, зафиксировать размер кнопки
                                            textStyle: TextStyle(
                                                fontSize:
                                                    12), // <-- Уменьшаем общий размер шрифта кнопки
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(height: 1, color: Colors.white54),
                // Player List
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          loc.players,
                          style: const TextStyle(
                              fontFamily: 'Geometria',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: players.length,
                          itemBuilder: (_, index) {
                            final player = players[index];
                            final isHostPlayer = player.name ==
                                host; // Assuming 'host' is a name
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              color: Colors.blueGrey[700],
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blueGrey[900],
                                  backgroundImage: player.avatarUrl != null
                                      ? CachedNetworkImageProvider(
                                          player.avatarUrl!)
                                      : null,
                                  child: player.avatarUrl == null
                                      ? Text(
                                          player.name
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: const TextStyle(
                                              fontSize: 18,
                                              color: Colors.white),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  player.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                                trailing: isHostPlayer
                                    ? const Icon(Icons.star,
                                        color: Colors.amber, size: 24)
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Room Settings and Action Buttons
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        loc.phaseTimes,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(loc.discussionTime,
                              style: TextStyle(color: Colors.white70)),
                          DropdownButton<int>(
                            value: _discussionTime,
                            dropdownColor: Theme.of(context).cardColor,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    color: Colors
                                        .white), // Стиль для отображаемого значения
                            items: [20, 30, 45, 60, 120, 180, 240]
                                .map(
                                  (value) => DropdownMenuItem<int>(
                                    value: value,
                                    child: Text(
                                      '$value ${loc.seconds}',
                                      style: TextStyle(
                                        color: widget.isDarkMode
                                            ? Colors.white
                                            : Colors
                                                .black, // Контрастный цвет текста
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (newValue) {
                              if (newValue != null) {
                                setState(() => _discussionTime = newValue);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (widget.playerName == host)
                            Expanded(
                              child: GestureDetector(
                                onTapDown: (_) => setState(
                                    () => _isStartGameButtonPressed = true),
                                onTapUp: (_) => setState(
                                    () => _isStartGameButtonPressed = false),
                                onTapCancel: () => setState(
                                    () => _isStartGameButtonPressed = false),
                                onTap: players.length >= 4
                                    ? () => _startGame(
                                        players.map((p) => p.id).toList())
                                    : null,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(
                                    begin: 1.0,
                                    end: _isStartGameButtonPressed ? 0.95 : 1.0,
                                  ),
                                  duration: const Duration(milliseconds: 100),
                                  builder: (context, scale, child) {
                                    return Transform.scale(
                                      scale: scale,
                                      child: ElevatedButton(
                                        onPressed: null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.green.shade700,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          textStyle: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        child: Text(loc.startGame),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTapDown: (_) => setState(
                                  () => _isLeaveRoomButtonPressed = true),
                              onTapUp: (_) => setState(
                                  () => _isLeaveRoomButtonPressed = false),
                              onTapCancel: () => setState(
                                  () => _isLeaveRoomButtonPressed = false),
                              onTap: _leaveRoom,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                  begin: 1.0,
                                  end: _isLeaveRoomButtonPressed ? 0.95 : 1.0,
                                ),
                                duration: const Duration(milliseconds: 100),
                                builder: (context, scale, child) {
                                  return Transform.scale(
                                    scale: scale,
                                    child: ElevatedButton(
                                      onPressed: null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        textStyle: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      child: Text(loc.leave),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
