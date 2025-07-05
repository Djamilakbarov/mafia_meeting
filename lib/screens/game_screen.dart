import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mafia_meeting/models/player_model.dart';
import 'package:mafia_meeting/models/role_enum.dart';
import 'package:mafia_meeting/widgets/player_card.dart';
import 'package:mafia_meeting/widgets/phase_banner.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mafia_meeting/screens/victory_screen.dart';
import 'package:mafia_meeting/screens/lobby_screen.dart';
import 'package:mafia_meeting/screens/waiting_room_screen.dart';
import 'package:mafia_meeting/screens/timer_controller.dart';
import 'package:mafia_meeting/services/chat_service.dart';
import 'package:mafia_meeting/services/rating_service.dart';
import 'package:mafia_meeting/services/webrtc_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mafia_meeting/models/game_phase.dart';
import 'package:mafia_meeting/widgets/google_ad_banner_widget.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mafia_meeting/signalling_service.dart';

class PostGameAdBanner extends StatelessWidget {
  final VoidCallback onContinue;
  const PostGameAdBanner({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(loc.ad),
      content: const GoogleAdBannerWidget(),
      actions: [
        TextButton(
          onPressed: onContinue,
          child: Text(loc.continueButton),
        ),
      ],
    );
  }
}

class GameScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;
  final String currentUserId;
  final Future<void> Function(bool) toggleTheme;
  final bool isDarkMode;

  const GameScreen({
    super.key,
    required this.roomCode,
    required this.playerName,
    required this.currentUserId,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Player> players = [];
  bool _historySaved = false;
  List<Player> winningPlayers = [];
  String? bestPlayerId;
  String? bestPlayerName;

  // Поле для WebRTCService, инициализируется в initState через Provider
  late WebRTCService _webrtcService;

  Map<String, bool> playerMicStatus = {};
  Map<String, bool> playerCamStatus = {};

  bool containsProfanity(String text) {
    final badWords = [
      'fuck',
      'shit',
      'bitch',
      'asshole',
      'хуй',
      'блядь',
      'сука'
    ];
    final lower = text.toLowerCase();
    return badWords.any((word) => lower.contains(word));
  }

  int _preparationTime = 15;
  int _discussionTime = 180;
  int _selfDefenseTime = 45;
  int _votingTime = 60;
  int _nightTime = 30;
  int _morningTime = 10;

  GamePhase _currentGamePhase = GamePhase.preparation;
  final TimerController _timerController = TimerController();
  Map<String, int> voteCounts = {};
  Map<String, int> playerLikes = {};
  bool gameOver = false;
  bool _adShown = false;
  String? _likedPlayer;
  String? winnerMessage;
  Map<String, dynamic> _lastNightActions = {}; // Для хранения результатов ночи

  late StreamSubscription<DocumentSnapshot> _roomSubscription;
  late StreamSubscription<QuerySnapshot> _likesSubscription;
  late StreamSubscription<QuerySnapshot> _peerStatusSubscription;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _listenToRoom();
    _listenToLikes();
    _listenToPeerStatus();
    _checkInitialLikeStatus();

    // Получаем WebRTCService и SignalingService из Provider
    _webrtcService = Provider.of<WebRTCService>(context,
        listen: false); // <-- Присваиваем полю _webrtcService
    final signalingService =
        Provider.of<SignalingService>(context, listen: false);

    // Инициализируем _webrtcService с помощью полученных сервисов
    _webrtcService.initialize(
        widget.roomCode, widget.currentUserId, signalingService);
    _webrtcService.initRenderers();
    _startPreparationPhase();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _timerController.cancel();
    _roomSubscription.cancel();
    _likesSubscription.cancel();
    _peerStatusSubscription.cancel();
    super.dispose();
  }

  Future<void> _saveGameHistory() async {
    if (_historySaved) return;
    _historySaved = true;

    final currentUserPlayer = players.firstWhere(
      (p) => p.id == widget.currentUserId,
      orElse: () => Player(
          id: widget.currentUserId,
          name: widget.playerName,
          role: Role.villager,
          isAlive: false),
    );

    final bool didWin = winningPlayers.any((p) => p.id == widget.currentUserId);

    final historyEntry = {
      'timestamp': FieldValue.serverTimestamp(),
      'userId': widget.currentUserId,
      'playerName': widget.playerName,
      'role': currentUserPlayer.role.name,
      'won': didWin,
      'likesReceived': playerLikes[widget.currentUserId] ?? 0,
      'isBestPlayer': bestPlayerId == currentUserPlayer.id,
      'roomCode': widget.roomCode,
    };

    final userDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId);

    await userDocRef.set({
      'gamesPlayed': FieldValue.increment(1),
      'gamesWon': didWin ? FieldValue.increment(1) : FieldValue.increment(0),
      'bestPlayerCount': (bestPlayerId == currentUserPlayer.id)
          ? FieldValue.increment(1)
          : FieldValue.increment(0),
    }, SetOptions(merge: true));

    await userDocRef.collection('history').add(historyEntry);
  }

  void _listenToRoom() {
    _roomSubscription = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.roomClosed)),
          );
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
        return;
      }

      final data = snapshot.data()!;
      final playersData = (data['players'] as List<dynamic>?)
              ?.map((e) => Player.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [];

      setState(() => players = playersData);

      if (data['roomSettings'] != null) {
        final rs = data['roomSettings'];
        _preparationTime = rs['preparationDuration'] ?? _preparationTime;
        _discussionTime = rs['discussionDuration'] ?? _discussionTime;
        _selfDefenseTime = rs['selfDefenseDuration'] ?? _selfDefenseTime;
        _votingTime = rs['votingDuration'] ?? _votingTime;
        _nightTime = rs['nightDuration'] ?? _nightTime;
        _morningTime = rs['morningDuration'] ?? _morningTime;
      }

      final phaseName = data['gamePhase'] as String?;
      if (phaseName != null) {
        final newPhase = GamePhase.values.firstWhere(
          (e) => e.name == phaseName,
          orElse: () => GamePhase.preparation,
        );
        if (newPhase != _currentGamePhase) {
          _setPhase(newPhase);
        }
      }

      // Сохраняем nightActions для использования при расчете рейтинга
      _lastNightActions = data['nightActions'] as Map<String, dynamic>? ?? {};

      final msg = data['winnerMessage'] as String?;
      if (msg != null && !gameOver) {
        gameOver = true;
        winnerMessage = msg;
        _determineWinningPlayersAndBestPlayer();
        _saveGameHistory();
        _applyRatingChanges(); // <-- Применяем изменения рейтинга
        _navigateToVictory();
        _showPostGameAd();
      }
    }, onError: (e) {
      debugPrint('Room listener error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${AppLocalizations.of(context)!.roomError}: $e')),
        );
      }
    });
  }

  void _listenToPeerStatus() {
    _peerStatusSubscription = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .collection('video_peers')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          for (var docChange in snapshot.docChanges) {
            final peerId = docChange.doc.id;
            final data = docChange.doc.data();
            if (data != null) {
              playerMicStatus[peerId] = data['isMicOn'] ?? true;
              playerCamStatus[peerId] = data['isCamOn'] ?? true;
            }
          }
        });
      }
    }, onError: (e) => debugPrint('Peer status listener error: $e'));
  }

  void _listenToLikes() {
    _likesSubscription = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .collection('ratings')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          playerLikes.clear();
          for (var doc in snapshot.docs) {
            final data = doc.data();
            playerLikes[doc.id] = data['likes'] ?? 0;
          }
        });
      }
    }, onError: (e) => debugPrint('Likes listener error: $e'));
  }

  Future<void> _checkInitialLikeStatus() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomCode)
          .collection('likes_meta')
          .doc(widget.currentUserId)
          .get();
      if (doc.exists && doc.data()!.containsKey('likedPlayerId')) {
        _likedPlayer = doc.data()!['likedPlayerId'] as String;
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Error checking initial like status: $e');
    }
  }

  void _setPhase(GamePhase phase) {
    if (_currentGamePhase == phase) return;

    _timerController.cancel();
    if (mounted) setState(() => _currentGamePhase = phase);

    switch (phase) {
      case GamePhase.preparation:
        _timerController.start(
            _preparationTime, () => _setPhase(GamePhase.discussion));
        break;
      case GamePhase.discussion:
        _timerController.start(
            _discussionTime, () => _setPhase(GamePhase.selfDefense));
        break;
      case GamePhase.selfDefense:
        final alivePlayersCount = players.where((p) => p.isAlive).length;
        _timerController.start(
            _selfDefenseTime * (alivePlayersCount > 0 ? alivePlayersCount : 1),
            () => _setPhase(GamePhase.voting));
        break;
      case GamePhase.voting:
        _timerController.start(
            _votingTime, () => _processVotesAndShowResults());
        break;
      case GamePhase.night:
        _timerController.start(
            _nightTime, () => _processNightActionsAndMorning());
        break;
      case GamePhase.morning:
        _timerController.start(
            _morningTime, () => _setPhase(GamePhase.discussion));
        break;
      case GamePhase.results:
        _timerController.start(phaseConfigs[GamePhase.results]!.durationSeconds,
            () {
          _checkGameEndCondition();
        });
        break;
      case GamePhase.gameOver:
        _timerController.cancel();
        break;
    }
    FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .update({'gamePhase': phase.name}).catchError(
            (e) => debugPrint('Phase update error: $e'));
  }

  void _startPreparationPhase() {
    _setPhase(GamePhase.preparation);
  }

  void _processNightActionsAndMorning() async {
    final roomDoc =
        await _firestore.collection('rooms').doc(widget.roomCode).get();
    final nightActions =
        roomDoc.data()?['nightActions'] as Map<String, dynamic>? ?? {};

    String? killed = nightActions['mafia'];
    String? healed = nightActions['doctor'];
    String? maniacKilled = nightActions['maniac'];

    // Обновляем _lastNightActions для использования при расчете рейтинга
    _lastNightActions = nightActions;

    if (killed != null && killed == healed) {
      killed = null;
    }

    List<Player> updatedPlayers = List.from(players);
    String? victimName;
    String? victimId; // <-- Добавлено для сохранения ID убитого

    if (maniacKilled != null) {
      int index = updatedPlayers.indexWhere((p) => p.id == maniacKilled);
      if (index != -1) {
        updatedPlayers[index] = updatedPlayers[index].copyWith(isAlive: false);
        victimName = updatedPlayers[index].name;
        victimId = updatedPlayers[index].id; // <-- Сохраняем ID
      }
    } else if (killed != null) {
      int index = updatedPlayers.indexWhere((p) => p.id == killed);
      if (index != -1) {
        updatedPlayers[index] = updatedPlayers[index].copyWith(isAlive: false);
        victimName = updatedPlayers[index].name;
        victimId = updatedPlayers[index].id; // <-- Сохраняем ID
      }
    }

    await _firestore.collection('rooms').doc(widget.roomCode).update({
      'players': updatedPlayers.map((p) => p.toMap()).toList(),
      'lastKilled': victimName,
      'lastKilledId': victimId, // <-- Сохраняем ID убитого
      'nightActions': {}, // Очищаем ночные действия после обработки
    });

    _setPhase(GamePhase.morning);
  }

  void _processVotesAndShowResults() async {
    final roomDoc =
        await _firestore.collection('rooms').doc(widget.roomCode).get();
    final currentVotes =
        roomDoc.data()?['votes'] as Map<String, dynamic>? ?? {};

    voteCounts.clear();
    currentVotes.forEach((voterId, votedForId) {
      if (votedForId != null &&
          votedForId is String &&
          players.any((p) => p.id == votedForId && p.isAlive)) {
        voteCounts[votedForId] = (voteCounts[votedForId] ?? 0) + 1;
      }
    });

    String? eliminatedPlayerId;
    int maxVotes = 0;
    List<String> playersWithMaxVotes = [];

    voteCounts.forEach((playerId, count) {
      if (count > maxVotes) {
        maxVotes = count;
        eliminatedPlayerId = playerId;
        playersWithMaxVotes = [playerId];
      } else if (count == maxVotes) {
        playersWithMaxVotes.add(playerId);
      }
    });

    if (playersWithMaxVotes.length > 1 || voteCounts.isEmpty) {
      eliminatedPlayerId = null;
    } else {
      eliminatedPlayerId = playersWithMaxVotes.first;
    }

    String? eliminatedPlayerName;
    if (eliminatedPlayerId != null) {
      eliminatedPlayerName =
          players.firstWhere((p) => p.id == eliminatedPlayerId).name;
      List<Player> updatedPlayers = List.from(players);
      int index = updatedPlayers.indexWhere((p) => p.id == eliminatedPlayerId);
      if (index != -1) {
        updatedPlayers[index] = updatedPlayers[index].copyWith(isAlive: false);

        await _firestore.collection('rooms').doc(widget.roomCode).update({
          'players': updatedPlayers.map((p) => p.toMap()).toList(),
          'eliminated': eliminatedPlayerName,
          'eliminatedId': eliminatedPlayerId, // <-- Сохраняем ID изгнанного
          'votes': {},
        });
      }
    } else {
      await _firestore.collection('rooms').doc(widget.roomCode).update({
        'eliminated': null,
        'eliminatedId': null, // <-- Убедимся, что ID тоже обнуляется
        'votes': {},
      });
    }

    try {
      await FirebaseFirestore.instance.collection('history').add({
        'roomCode': widget.roomCode,
        'timestamp': FieldValue.serverTimestamp(),
        'players': players.map((p) => p.toMap()).toList(),
        'voteResult': currentVotes,
        'eliminated': eliminatedPlayerName,
        'eliminatedId': eliminatedPlayerId, // <-- Сохраняем ID в истории
      });
    } catch (e) {
      print("Ошибка при добавлении истории игры ($widget.roomCode): $e");
    }

    _setPhase(GamePhase.results);
    _showVoteResultsDialog(eliminatedPlayerName);
  }

  void _showVoteResultsDialog(String? eliminatedPlayerName) {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(loc.voteResults),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (eliminatedPlayerName != null)
                Text('${loc.playerEliminated}: $eliminatedPlayerName',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              if (eliminatedPlayerName == null && voteCounts.isNotEmpty)
                Text(loc.noOneEliminated,
                    style: const TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 10),
              Text(loc.allVotes),
              ...voteCounts.entries.map((e) {
                final playerName = players
                    .firstWhere((p) => p.id == e.key,
                        orElse: () => Player(
                            id: e.key,
                            name: 'Unknown Player',
                            role: Role.villager))
                    .name;
                return Text('${playerName}: ${e.value}');
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkGameEndCondition();
            },
            child: Text(loc.ok),
          ),
        ],
      ),
    );
  }

  void _checkGameEndCondition() {
    final mafiaCount =
        players.where((p) => p.isAlive && p.role == Role.mafia).length;
    final villagersCount = players
        .where((p) =>
            p.isAlive &&
            (p.role == Role.villager ||
                p.role == Role.doctor ||
                p.role == Role.detective))
        .length;
    final maniacCount =
        players.where((p) => p.isAlive && p.role == Role.maniac).length;

    String? winner;
    String? message;

    if (mafiaCount >= villagersCount && mafiaCount > 0) {
      winner = 'mafia';
      message = AppLocalizations.of(context)!.mafiaWins;
    } else if (mafiaCount == 0 && maniacCount == 0) {
      winner = 'villagers';
      message = AppLocalizations.of(context)!.villagersWin;
    } else if (maniacCount > 0 && mafiaCount == 0 && villagersCount == 0 ||
        (maniacCount > 0 && maniacCount >= (mafiaCount + villagersCount))) {
      winner = 'maniac';
      message = AppLocalizations.of(context)!.maniacWins;
    }

    if (winner != null && !gameOver) {
      gameOver = true;
      winnerMessage = message;
      FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomCode)
          .update({
        'winnerMessage': winnerMessage,
        'gamePhase': GamePhase.gameOver.name,
      });
    } else if (winner == null && _currentGamePhase == GamePhase.results) {
      _setPhase(GamePhase.night);
    }
  }

  void _determineWinningPlayersAndBestPlayer() {
    if (winnerMessage == null) return;

    if (winnerMessage!
        .contains(AppLocalizations.of(context)!.mafiaWins.split(' ')[0])) {
      winningPlayers = players.where((p) => p.role == Role.mafia).toList();
    } else if (winnerMessage!
        .contains(AppLocalizations.of(context)!.villagersWin.split(' ')[0])) {
      winningPlayers = players
          .where((p) =>
              p.role == Role.villager ||
              p.role == Role.doctor ||
              p.role == Role.detective)
          .toList();
    } else if (winnerMessage!
        .contains(AppLocalizations.of(context)!.maniacWins.split(' ')[0])) {
      winningPlayers = players.where((p) => p.role == Role.maniac).toList();
    }

    if (playerLikes.isNotEmpty) {
      String? topPlayerId;
      int maxLikes = -1;

      playerLikes.forEach((currentLikedPlayerId, likes) {
        final likedPlayerObj = players.firstWhere(
            (p) => p.id == currentLikedPlayerId,
            orElse: () => Player(id: '', name: '', role: Role.villager));
        if (likedPlayerObj.id.isNotEmpty && likes > maxLikes) {
          maxLikes = likes;
          topPlayerId = likedPlayerObj.id;
        }
      });
      bestPlayerId = topPlayerId;
      bestPlayerName = players
          .firstWhere((p) => p.id == bestPlayerId,
              orElse: () =>
                  Player(id: '', name: 'Unknown', role: Role.villager))
          .name;
    } else {
      bestPlayerId = null;
      bestPlayerName = null;
    }
  }

  // НОВЫЙ МЕТОД: Расчет и применение изменений рейтинга
  Future<void> _applyRatingChanges() async {
    // final loc = AppLocalizations.of(context)!; // Удалено, так как не используется
    if (winnerMessage == null) return;

    // Базовые очки
    const int winPoints = 10;
    const int losePoints = -1; // Очки за поражение (по вашему запросу)
    const int bestPlayerBonus = 5; // Бонус за "Лучшего игрока"

    // Бонусы за успешные действия ролей
    const int mafiaSuccessfulKillBonus = 7;
    const int mafiaSpecialRoleKillBonus = 10; // Больше за доктора/детектива
    const int doctorSuccessfulSaveBonus = 7;
    const int detectiveCorrectGuessBonus = 7;
    const int maniacSuccessfulKillBonus = 7;
    const int villagerCorrectVoteBonus = 5; // За правильное голосование

    // Получаем ID игрока, который был изгнан голосованием
    final roomDoc =
        await _firestore.collection('rooms').doc(widget.roomCode).get();
    final String? eliminatedPlayerId =
        roomDoc.data()?['eliminatedId'] as String?;
    final String? lastKilledId =
        roomDoc.data()?['lastKilledId'] as String?; // Получаем ID убитого ночью

    for (var player in players) {
      int ratingChange = 0;
      bool didWin = winningPlayers.any((p) => p.id == player.id);

      // 1. Очки за победу/поражение команды
      if (didWin) {
        ratingChange += winPoints;
      } else {
        ratingChange += losePoints;
      }

      // 2. Бонусы за успешные действия ролей (только для живых игроков)
      if (player.isAlive) {
        switch (player.role) {
          case Role.mafia:
            final mafiaTargetId = _lastNightActions['mafia']; // Цель мафии
            final doctorHealId = _lastNightActions['doctor']; // Цель доктора
            if (mafiaTargetId != null &&
                mafiaTargetId == lastKilledId &&
                mafiaTargetId != doctorHealId) {
              // Мафия успешно убила цель, и цель не была спасена доктором
              final killedPlayer = players.firstWhere(
                  (p) => p.id == mafiaTargetId,
                  orElse: () => Player(id: '', name: '', role: Role.villager));
              if (killedPlayer.role == Role.doctor ||
                  killedPlayer.role == Role.detective) {
                ratingChange +=
                    mafiaSpecialRoleKillBonus; // Больше за важную роль
              } else {
                ratingChange += mafiaSuccessfulKillBonus;
              }
            }
            break;
          case Role.doctor:
            // Доктор получает бонус, если он успешно спас игрока, которого пытались убить
            final killedByMafiaId = _lastNightActions['mafia'];
            final healedById = _lastNightActions['doctor'];
            if (killedByMafiaId != null &&
                healedById == player.id &&
                killedByMafiaId == healedById) {
              ratingChange += doctorSuccessfulSaveBonus; // За успешное спасение
            }
            break;
          case Role.detective:
            // Детектив получает бонус, если он успешно проверил мафию или маньяка
            final investigatedId = _lastNightActions['detective'];
            if (investigatedId != null) {
              final investigatedPlayer = players.firstWhere(
                  (p) => p.id == investigatedId,
                  orElse: () => Player(id: '', name: '', role: Role.villager));
              if (investigatedPlayer.role == Role.mafia ||
                  investigatedPlayer.role == Role.maniac) {
                ratingChange +=
                    detectiveCorrectGuessBonus; // За правильное определение
              }
            }
            break;
          case Role.maniac:
            // Маньяк получает бонус, если успешно убил цель
            final maniacTargetId = _lastNightActions['maniac'];
            if (maniacTargetId != null && maniacTargetId == lastKilledId) {
              ratingChange += maniacSuccessfulKillBonus;
            }
            break;
          case Role.villager:
            // Мирный житель получает бонус, если его голос помог изгнать мафию/маньяка
            if (eliminatedPlayerId != null) {
              final eliminatedPlayer = players.firstWhere(
                  (p) => p.id == eliminatedPlayerId,
                  orElse: () => Player(id: '', name: '', role: Role.villager));
              if (eliminatedPlayer.role == Role.mafia ||
                  eliminatedPlayer.role == Role.maniac) {
                // Проверяем, голосовал ли этот мирный житель за изгнанного мафию/маньяка
                final Map<String, dynamic> currentVotes =
                    roomDoc.data()?['votes'] as Map<String, dynamic>? ?? {};
                if (currentVotes[player.id] == eliminatedPlayerId) {
                  // Проверяем, что игрок голосовал за изгнанного
                  ratingChange += villagerCorrectVoteBonus;
                }
              }
            }
            break;
        }
      }

      // 3. Бонус за "Лучшего игрока" (если игрок был признан лучшим)
      if (bestPlayerId != null && player.id == bestPlayerId) {
        ratingChange += bestPlayerBonus;
      }

      // Применяем изменение рейтинга
      await RatingService.updatePlayerRating(player.id, ratingChange);
      print(
          "Рейтинг игрока ${player.name} (ID: ${player.id}) изменен на $ratingChange. Текущий рейтинг: (будет обновлен в профиле)");
    }
  }

  void _submitLike(String targetPlayerId) async {
    final loc = AppLocalizations.of(context)!;

    final targetPlayer = players.firstWhere((p) => p.id == targetPlayerId,
        orElse: () =>
            Player(id: targetPlayerId, name: 'Unknown', role: Role.villager));
    final targetPlayerName = targetPlayer.name;

    if (_likedPlayer != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.alreadyLiked)),
      );
      return;
    }
    if (targetPlayerId == widget.currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.cannotLikeSelf)),
      );
      return;
    }

    final ref = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .collection('likes_meta')
        .doc(widget.currentUserId);
    await ref.set({
      'likedPlayerId': targetPlayerId,
      'timestamp': FieldValue.serverTimestamp()
    });

    setState(() {
      _likedPlayer = targetPlayerId;
      final likedPlayerIndex =
          players.indexWhere((p) => p.id == targetPlayerId);
      if (likedPlayerIndex != -1) {
        final updatedPlayer = players[likedPlayerIndex].copyWith(
          likesReceived: players[likedPlayerIndex].likesReceived + 1,
        );
        players[likedPlayerIndex] = updatedPlayer;
      }
    });

    await RatingService.likePlayer(
        widget.roomCode, targetPlayerId, widget.currentUserId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.likedPlayer(targetPlayerName))),
      );
    }
  }

  void _submitVote(String targetPlayerId) async {
    final loc = AppLocalizations.of(context)!;
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .update({
      'votes.${widget.currentUserId}': targetPlayerId,
    });

    if (mounted) {
      final votedForName = players
          .firstWhere((p) => p.id == targetPlayerId,
              orElse: () => Player(
                  id: targetPlayerId, name: 'Unknown', role: Role.villager))
          .name;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.votedFor} $votedForName')),
      );
    }
  }

  void _submitNightAction(String targetPlayerId, Role actionRole) async {
    final loc = AppLocalizations.of(context)!;
    String actionKey;
    switch (actionRole) {
      case Role.mafia:
        actionKey = 'mafia';
        break;
      case Role.doctor:
        actionKey = 'doctor';
        break;
      case Role.detective:
        actionKey = 'detective';
        break;
      case Role.maniac:
        actionKey = 'maniac';
        break;
      case Role.villager:
        return;
    }

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .update({
      'nightActions.${actionKey}': targetPlayerId,
    });

    if (mounted) {
      final targetName = players
          .firstWhere((p) => p.id == targetPlayerId,
              orElse: () => Player(
                  id: targetPlayerId, name: 'Unknown', role: Role.villager))
          .name;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.actionSubmitted} $targetName')),
      );
    }
  }

  void _navigateToVictory() {
    if (Navigator.of(context).canPop() &&
        ModalRoute.of(context)?.settings.name == '/victory') {
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/victory'),
        builder: (_) => VictoryScreen(
          winnerTeam: winnerMessage!.contains(
                  AppLocalizations.of(context)!.mafiaWins.split(' ')[0])
              ? 'mafia'
              : (winnerMessage!.contains(
                      AppLocalizations.of(context)!.villagersWin.split(' ')[0])
                  ? 'villagers'
                  : 'maniac'),
          message: winnerMessage!,
          onPlayAgain: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => WaitingRoomScreen(
                  roomCode: widget.roomCode,
                  playerName: widget.playerName,
                  currentUserId: widget.currentUserId,
                  toggleTheme: widget.toggleTheme,
                  isDarkMode: widget.isDarkMode,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showPostGameAd() {
    if (!_adShown && gameOver) {
      _adShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => PostGameAdBanner(
          onContinue: () => Navigator.pop(context),
        ),
      );
    }
  }

  Widget _buildVideoSection(AppLocalizations loc, WebRTCService webRTCService) {
    return Column(
      children: [
        Expanded(
          child: webRTCService.localStream != null
              ? RTCVideoView(webRTCService.localRenderer, mirror: true)
              : Center(child: Text(loc.cameraLoading)),
        ),
        if (webRTCService.remoteRenderers.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: webRTCService.remoteRenderers.length,
              itemBuilder: (_, i) {
                final peerId = webRTCService.remoteRenderers.keys.elementAt(i);
                final player = players.firstWhere((p) => p.id == peerId,
                    orElse: () => Player(
                        id: peerId,
                        name: peerId,
                        role: Role.villager,
                        isAlive: false));

                final bool micStatus = playerMicStatus[peerId] ?? true;
                final bool camStatus = playerCamStatus[peerId] ?? true;

                return Container(
                  width: 120,
                  margin: const EdgeInsets.all(4),
                  color: Colors.black,
                  child: Stack(
                    children: [
                      RTCVideoView(webRTCService.remoteRenderers[peerId]!,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                      if (!player.isAlive)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black54,
                            child: Center(
                              child: Text(loc.eliminated,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 16)),
                            ),
                          ),
                        ),
                      if (!micStatus && player.isAlive)
                        const Positioned(
                          top: 4,
                          left: 4,
                          child: Icon(Icons.mic_off,
                              color: Colors.redAccent, size: 20),
                        ),
                      if (!camStatus && player.isAlive)
                        const Positioned(
                          top: 4,
                          right: 4,
                          child: Icon(Icons.videocam_off,
                              color: Colors.redAccent, size: 20),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final localPlayer = players.firstWhere(
      (p) => p.id == widget.currentUserId,
      orElse: () => Player(
          id: widget.currentUserId,
          name: widget.playerName,
          role: Role.villager,
          isAlive: false),
    );

    Widget phaseUI;
    switch (_currentGamePhase) {
      case GamePhase.preparation:
        phaseUI = Center(child: Text(loc.roleDistribution));
        break;
      case GamePhase.discussion:
        phaseUI = Column(
          children: [
            Expanded(flex: 2, child: _buildVideoSection(loc, _webrtcService)),
            const Divider(),
            Expanded(
              flex: 1,
              child: StreamBuilder<QuerySnapshot>(
                stream: ChatService.getChatStream(widget.roomCode),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('${loc.chatError}: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final messageData =
                          messages[index].data() as Map<String, dynamic>;
                      final senderId =
                          messageData['sender'] as String? ?? 'Unknown';
                      final senderName = players
                          .firstWhere((p) => p.id == senderId,
                              orElse: () => Player(
                                  id: senderId,
                                  name: senderId,
                                  role: Role.villager))
                          .name;

                      return ListTile(
                        title: Text(senderName),
                        subtitle: Text(messageData['message'] ?? ''),
                        trailing: Text(
                          (messageData['timestamp'] as Timestamp)
                              .toDate()
                              .toString()
                              .split(' ')[1]
                              .substring(0, 5),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ChatService.messageController,
                      decoration: InputDecoration(labelText: loc.message),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      final text = ChatService.messageController.text;
                      ChatService.sendMessage(
                          widget.roomCode, widget.currentUserId, text);
                    },
                  ),
                ],
              ),
            ),
          ],
        );
        break;
      case GamePhase.selfDefense:
        phaseUI = Column(
          children: [
            Expanded(flex: 2, child: _buildVideoSection(loc, _webrtcService)),
            Expanded(
              child: ListView(
                children: players
                    .where((p) => p.isAlive && p.id != widget.currentUserId)
                    .map((p) => ListTile(
                          title: Text(p.name),
                          trailing: ElevatedButton(
                            onPressed: _likedPlayer == null
                                ? () => _submitLike(p.id)
                                : null,
                            child: Text(loc.like),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        );
        break;
      case GamePhase.voting:
        phaseUI = Column(
          children: [
            Expanded(flex: 2, child: _buildVideoSection(loc, _webrtcService)),
            Expanded(
              child: ListView(
                children: players
                    .where((p) => p.isAlive && p.id != widget.currentUserId)
                    .map((p) => ListTile(
                          title: Text(p.name),
                          trailing: ElevatedButton(
                            onPressed: () {
                              _submitVote(p.id);
                            },
                            child: Text(loc.castVote),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        );
        break;
      case GamePhase.night:
        final isMafia = localPlayer.role == Role.mafia;
        final isDoctor = localPlayer.role == Role.doctor;
        final isDetective = localPlayer.role == Role.detective;
        final isManiac = localPlayer.role == Role.maniac;

        phaseUI = Column(
          children: [
            Expanded(flex: 2, child: _buildVideoSection(loc, _webrtcService)),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(loc.nightPhaseInfo,
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 10),
                    if (isMafia || isDoctor || isDetective || isManiac)
                      Text(loc.chooseTarget,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView(
                        children: players
                            .where((p) =>
                                p.id != widget.currentUserId && p.isAlive)
                            .map((p) {
                          return ListTile(
                            title: Text(p.name),
                            trailing:
                                (isMafia || isDoctor || isDetective || isManiac)
                                    ? ElevatedButton(
                                        onPressed: () => _submitNightAction(
                                            p.id, localPlayer.role),
                                        child: Text(isMafia
                                            ? loc.mafiaAction
                                            : (isDoctor
                                                ? loc.doctorAction
                                                : (isDetective
                                                    ? loc.detectiveAction
                                                    : (isManiac
                                                        ? loc.maniacAction
                                                        : 'Action')))),
                                      )
                                    : null,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
        break;
      case GamePhase.morning:
        phaseUI = Column(
          children: [
            Expanded(flex: 2, child: _buildVideoSection(loc, _webrtcService)),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(loc.morningPhaseInfo,
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 10),
                    FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: FirebaseFirestore.instance
                          .collection('rooms')
                          .doc(widget.roomCode)
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }
                        if (snapshot.hasError) {
                          return Text('${loc.error}: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red));
                        }
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final roomData = snapshot.data!.data();
                          final lastKilledName = roomData?['lastKilled'];

                          if (lastKilledName != null) {
                            return Text(
                              '${loc.lastNightVictim}: $lastKilledName',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red),
                              textAlign: TextAlign.center,
                            );
                          }
                        }
                        return Text(loc.noVictim,
                            style: const TextStyle(fontSize: 18));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
        break;
      case GamePhase.results:
        phaseUI = Center(child: Text(loc.processingResults));
        break;
      case GamePhase.gameOver:
        phaseUI = Center(child: Text(loc.gameOver));
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${loc.room}: ${widget.roomCode} - ${loc.yourRole}: ${localPlayer.role.name}'),
      ),
      body: Column(
        children: [
          ListenableBuilder(
            listenable: _timerController,
            builder: (_, __) => PhaseBanner(
              phase: _currentGamePhase.name,
              duration: _timerController.timeLeft,
            ),
          ),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.8,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              padding: const EdgeInsets.all(8),
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                final isCurrentUser = player.id == widget.currentUserId;
                final rtcRenderer = _webrtcService.remoteRenderers[player.id];

                final bool micStatus = playerMicStatus[player.id] ?? true;
                final bool camStatus = playerCamStatus[player.id] ?? true;

                return PlayerCard(
                  player: player,
                  isCurrentUser: isCurrentUser,
                  rtcRenderer: rtcRenderer,
                  isMicOn: micStatus,
                  isCamOn: camStatus,
                  onTap: () {
                    if (_currentGamePhase == GamePhase.voting) {
                      _submitVote(player.id);
                    } else if (_currentGamePhase == GamePhase.night) {
                      _submitNightAction(player.id, localPlayer.role);
                    } else if (_currentGamePhase == GamePhase.selfDefense) {
                      _submitLike(player.id);
                    }
                  },
                );
              },
            ),
          ),
          const Divider(),
          Expanded(flex: 1, child: phaseUI),
          if (bestPlayerName != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '👑 ${loc.bestPlayer}: $bestPlayerName',
                style: const TextStyle(
                    fontFamily: 'Geometria', fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
