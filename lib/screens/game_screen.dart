import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../models/player_model.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';

enum GamePhase { night, discussion, voting, result }

GamePhase parseGamePhase(String phase) {
  switch (phase) {
    case 'night': return GamePhase.night;
    case 'discussion': return GamePhase.discussion;
    case 'voting': return GamePhase.voting;
    case 'result': return GamePhase.result;
    default: return GamePhase.night;
  }
}

class GameScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;

  const GameScreen({super.key, required this.roomCode, required this.playerName});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Game state
  List<Player> players = [];
  Player? currentPlayer;
  String? selectedTarget;
  GamePhase currentPhase = GamePhase.night;
  late StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> _roomSub;
  List<String> gameLog = [];

  // WebRTC
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  final Map<String, String> _remotePlayerNames = {};
  MediaStream? _localStream;
  bool _micEnabled = true;
  bool _camEnabled = true;
  late StreamSubscription<QuerySnapshot<Map<String, dynamic>>> _videoSub;
  final String _id = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    _initVideoCall();
    _subscribeToRoom();
    _listenForRemoteVideos();
    _addToGameLog("Игра началась!");
  }

  Future<void> _initVideoCall() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': _camEnabled ? {'facingMode': 'user'} : false,
      });
      _localRenderer.srcObject = stream;
      _localStream = stream;

      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomCode)
          .collection('video')
          .doc(_id)
          .set({
        'id': _id,
        'name': widget.playerName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isAlive': true
      });
    } catch (e) {
      _addToGameLog("Ошибка видео: ${e.toString()}");
    }
  }

  void _listenForRemoteVideos() {
    _videoSub = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .collection('video')
        .where('isAlive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        final doc = change.doc;
        if (doc.id == _id) continue;

        if (change.type == DocumentChangeType.removed) {
          _removeRenderer(doc.id);
        } else {
          _updateRenderer(doc);
        }
      }
    });
  }

  void _updateRenderer(DocumentSnapshot doc) async {
    if (!_remoteRenderers.containsKey(doc.id)) {
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      setState(() {
        _remoteRenderers[doc.id] = renderer;
        _remotePlayerNames[doc.id] = doc['name'];
      });
    }
  }

  void _removeRenderer(String id) {
    if (_remoteRenderers.containsKey(id)) {
      _remoteRenderers[id]?.dispose();
      setState(() {
        _remoteRenderers.remove(id);
        _remotePlayerNames.remove(id);
      });
    }
  }

  void _toggleMic() {
    setState(() {
      _micEnabled = !_micEnabled;
      _localStream?.getAudioTracks().forEach((track) {
        track.enabled = _micEnabled;
      });
      _addToGameLog(_micEnabled ? "Микрофон включен" : "Микрофон выключен");
    });
  }

  void _toggleCamera() {
    setState(() {
      _camEnabled = !_camEnabled;
      _localStream?.getVideoTracks().forEach((track) {
        track.enabled = _camEnabled;
      });
      _addToGameLog(_camEnabled ? "Камера включена" : "Камера выключена");
    });
  }

  void _subscribeToRoom() {
    _roomSub = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final playerList = List<Map<String, dynamic>>.from(data['players'] ?? []);
      final phase = data['phase'] ?? 'night';

      final winMessage = _checkWinConditionRealtime(playerList);
      if (winMessage != null) {
        _showWinDialog(winMessage);
        return;
      }

      setState(() {
        players = playerList.map((p) => Player.fromMap(p)).toList();
        currentPhase = parseGamePhase(phase);
        currentPlayer = players.firstWhere((p) => p.name == widget.playerName);
      });

      _updateVideoStatuses();
    });
  }

  void _updateVideoStatuses() async {
    for (var player in players) {
      if (!player.isAlive) {
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomCode)
            .collection('video')
            .where('name', isEqualTo: player.name)
            .get()
            .then((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.update({'isAlive': false});
          }
        });
      }
    }
  }

  void _submitNightAction() async {
    if (selectedTarget == null) return;

    String actionType = '';
    String actionMessage = '';

    switch (currentPlayer!.role) {
      case Role.mafia:
      case Role.maniac:
        actionType = 'attack';
        actionMessage = 'атаковал';
        break;
      case Role.doctor:
        actionType = 'heal';
        actionMessage = 'вылечил';
        break;
      case Role.detective:
        actionType = 'investigate';
        actionMessage = 'проверил';
        break;
      default:
        return;
    }

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .update({
      'lastAction': {
        'by': currentPlayer!.name,
        'target': selectedTarget,
        'role': currentPlayer!.role.name,
        'type': actionType
      },
      'phase': 'discussion'
    });

    _addToGameLog(
        '${currentPlayer!.name} $actionMessage $selectedTarget');

    setState(() {
      currentPhase = GamePhase.discussion;
      selectedTarget = null;
    });
  }

  void _accuse(String name) {
    setState(() {
      selectedTarget = name;
      currentPhase = GamePhase.voting;
    });
    _addToGameLog('${currentPlayer!.name} обвиняет $name');
  }

  void _voteVerdict(bool kill) async {
    if (selectedTarget == null) return;

    String result = kill ? 'казнить' : 'помиловать';
    _addToGameLog('Голосование: $result $selectedTarget');

    if (kill) {
      int index = players.indexWhere((p) => p.name == selectedTarget);
      if (index != -1) {
        players[index] = players[index].copyWith(isAlive: false);

        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomCode)
            .update({
          'players': players.map((p) => p.toMap()).toList(),
          'lastVote': {
            'by': currentPlayer!.name,
            'target': selectedTarget,
            'result': 'eliminated'
          }
        });

        _updateVideoStatuses();
      }
    }

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .update({'phase': 'result'});

    setState(() {
      currentPhase = GamePhase.result;
      selectedTarget = null;
    });
  }

  void _restartGame() async {
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .update({
      'phase': 'night',
      'lastAction': FieldValue.delete(),
      'lastVote': FieldValue.delete()
    });

    _addToGameLog("Игра перезапущена");

    setState(() {
      currentPhase = GamePhase.night;
      selectedTarget = null;
    });
  }

  String? _checkWinConditionRealtime(List<Map<String, dynamic>> rawPlayers) {
    final players = rawPlayers.map((p) => Player.fromMap(p)).toList();
    int mafiaAlive = players.where((p) => p.isAlive && p.role == Role.mafia).length;
    int othersAlive = players.where((p) => p.isAlive && p.role != Role.mafia).length;

    if (mafiaAlive == 0) return "Мирные победили!";
    if (mafiaAlive >= othersAlive) return "Мафия победила!";
    return null;
  }

  void _showWinDialog(String message) {
    _addToGameLog(message);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Игра окончена"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _restartGame();
            },
            child: const Text("Новая игра"),
          ),
        ],
      ),
    );
  }

  void _addToGameLog(String message) {
    setState(() {
      gameLog.add('${DateTime.now().hour}:${DateTime.now().minute} - $message');
      if (gameLog.length > 50) gameLog.removeAt(0);
    });
  }

  @override
  void dispose() {
    _roomSub.cancel();
    _videoSub.cancel();
    _localRenderer.dispose();
    _localStream?.dispose();
    for (final renderer in _remoteRenderers.values) {
      renderer.dispose();
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
    final loc = AppLocalizations.of(context)!;
    final alivePlayers = players.where((p) => p.isAlive).toList();
    final others = alivePlayers.where((p) => p.name != widget.playerName).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${loc.day1} (${_getPhaseText(loc)})'),
        actions: [
          IconButton(
            icon: Icon(_micEnabled ? Icons.mic : Icons.mic_off),
            onPressed: _toggleMic,
          ),
          IconButton(
            icon: Icon(_camEnabled ? Icons.videocam : Icons.videocam_off),
            onPressed: _toggleCamera,
          ),
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () {
              final locale = Localizations.localeOf(context).languageCode;
              if (locale == 'en') {
                MafiaMeetingApp.setLocale(context, const Locale('ru'));
              } else if (locale == 'ru') {
                MafiaMeetingApp.setLocale(context, const Locale('az'));
              } else {
                MafiaMeetingApp.setLocale(context, const Locale('en'));
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Видеопанель
          _buildVideoPanel(),
          // Игровая панель
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.people),
                      Tab(icon: Icon(Icons.history)),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildPlayerList(alivePlayers),
                        _buildGameLog(),
                      ],
                    ),
                  ),
                  // Фазовые действия
                  if (currentPhase == GamePhase.night) 
                    _buildNightActions(loc, others),
                  if (currentPhase == GamePhase.discussion) 
                    _buildDiscussionActions(loc, others),
                  if (currentPhase == GamePhase.voting) 
                    _buildVotingActions(loc),
                  if (currentPhase == GamePhase.result) 
                    _buildResultActions(loc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPanel() {
    return Container(
      height: 200,
      color: Colors.black,
      child: Column(
        children: [
          // Локальное видео
          Expanded(
            child: Stack(
              children: [
                RTCVideoView(_localRenderer, mirror: true),
                RTCVideoView(_remoteRenderer);
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    color: Colors.black54,
                    child: Text(
                      '${widget.playerName} (Вы)',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Удаленные видео
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _remoteRenderers.length,
              itemBuilder: (ctx, index) {
                final id = _remoteRenderers.keys.elementAt(index);
                return Container(
                  width: 120,
                  margin: const EdgeInsets.all(4),
                  child: Stack(
                    children: [
                      RTCVideoView(_remoteRenderers[id]!),
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          color: Colors.black54,
                          child: Text(
                            _remotePlayerNames[id] ?? 'Игрок',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerList(List<Player> alivePlayers) {
    return ListView.builder(
      itemCount: alivePlayers.length,
      itemBuilder: (context, index) {
        final player = alivePlayers[index];
        final isYou = player.name == widget.playerName;

        return Card(
          color: isYou ? Colors.blue[900] : Colors.grey[900],
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getRoleColor(player.role),
              child: Text(player.name[0]),
            ),
            title: Text(
              player.name + (isYou ? " (вы)" : ""),
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              isYou ? "Роль: ${player.roleName}" : "Статус: жив",
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: Icon(
              Icons.circle,
              color: Colors.green,
              size: 12,
            ),
          ),
        );
      },
    );
  }

  Widget _buildGameLog() {
    return ListView.builder(
      reverse: true,
      itemCount: gameLog.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Text(gameLog.reversed.toList()[index]),
        );
      },
    );
  }

  Widget _buildNightActions(AppLocalizations loc, List<Player> targets) {
    if (currentPlayer == null) return Container();

    if (!currentPlayer!.isActiveRole) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Вы ${currentPlayer!.roleName}. Ночью вы спите...",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitNightAction,
              child: const Text("Продолжить"),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Вы ${currentPlayer!.roleName}. Выберите цель:",
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            isExpanded: true,
            hint: const Text("Выберите игрока"),
            value: selectedTarget,
            items: targets
                .map((p) => DropdownMenuItem(
                      value: p.name,
                      child: Text(p.name),
                    ))
                .toList(),
            onChanged: (value) => setState(() => selectedTarget = value),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: selectedTarget != null ? _submitNightAction : null,
            child: Text(currentPlayer!.role == Role.doctor
                ? "Лечить"
                : currentPlayer!.role == Role.detective
                    ? "Проверить"
                    : "Атаковать"),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscussionActions(AppLocalizations loc, List<Player> targets) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Фаза обсуждения. Выберите подозреваемого:",
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            isExpanded: true,
            hint: const Text("Выберите игрока"),
            value: selectedTarget,
            items: targets
                .map((p) => DropdownMenuItem(
                      value: p.name,
                      child: Text(p.name),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) _accuse(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVotingActions(AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Голосование: $selectedTarget",
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () => _voteVerdict(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Казнить"),
              ),
              ElevatedButton(
                onPressed: () => _voteVerdict(false),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text("Помиловать"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultActions(AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            "Результаты голосования",
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _restartGame,
            child: const Text("Следующий день"),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(Role role) {
    switch (role) {
      case Role.mafia: return Colors.red;
      case Role.maniac: return Colors.purple;
      case Role.doctor: return Colors.blue;
      case Role.detective: return Colors.green;
      case Role.villager: return Colors.grey;
    }
  }

  String _getPhaseText(AppLocalizations loc) {
    switch (currentPhase) {
      case GamePhase.night: return "Ночь";
      case GamePhase.discussion: return loc.phaseDiscussion;
      case GamePhase.voting: return loc.phaseVoting;
      case GamePhase.result: return loc.phaseResult;
    }
  }
}