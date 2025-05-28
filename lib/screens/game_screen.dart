import 'dart:async'; // Добавлен импорт для StreamSubscription
import '../widgets/ads_banner_widget.dart';
import 'video_call_screen.dart';
import 'victory_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/player_model.dart';
import 'timer_controller.dart';
import '../services/chat_service.dart';
import '../services/rating_service.dart';
import '../models/role_enum.dart'; // Убедитесь, что Role_enum.dart определен и доступен

// Новая фаза игры
enum GamePhase { discussion, voting, night, results, finished }

class PostGameAdBanner extends StatelessWidget {
  final VoidCallback onContinue;
  const PostGameAdBanner({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Реклама'),
      content: const AdsBannerWidget(),
      actions: [
        TextButton(
          onPressed: onContinue,
          child: const Text('Продолжить'),
        ),
      ],
    );
  }
}

class GameScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;

  const GameScreen(
      {super.key, required this.roomCode, required this.playerName});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Map<String, String> voteResults = {};
  int _discussionTime =
      120; // Значение по умолчанию, будет загружено из Firestore
  late TimerController _timerController; // Инициализируем в _loadDiscussionTime
  List<Player> players = [];
  Map<String, int> ratings = {};
  String? bestPlayer;
  String? winnerMessage;
  bool gameOver = false;
  bool _adShown = false;
  String? _likedPlayer; // Игрок, которого текущий пользователь уже лайкнул

  GamePhase _currentGamePhase = GamePhase.discussion; // Начальная фаза игры

  // StreamSubscription для отслеживания изменений в комнате
  late StreamSubscription<DocumentSnapshot> _roomSubscription;
  // StreamSubscription для отслеживания изменений в лайках
  late StreamSubscription<QuerySnapshot> _likesSubscription;

  @override
  void initState() {
    super.initState();
    _loadDiscussionTime(); // Загружаем время и инициализируем таймер
    _listenToRoom();
    _listenToLikes();
    _checkInitialLikeStatus(); // Проверяем статус лайка при инициализации
  }

  @override
  void dispose() {
    _timerController.cancel();
    _roomSubscription.cancel();
    _likesSubscription.cancel();
    super.dispose();
  }

  // --- Методы для загрузки данных и слушателей ---

  void _loadDiscussionTime() async {
    final doc = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .get();
    if (doc.exists && doc.data()!.containsKey('discussionTime')) {
      setState(() {
        _discussionTime = doc['discussionTime'];
        // Инициализируем _timerController здесь, после загрузки _discussionTime
        _timerController = TimerController();
        // Запускаем таймер с загруженным _discussionTime и колбэком
        _timerController.start(
          _discussionTime, // duration
          () {
            // onEnd callback: Что должно произойти, когда таймер закончится
            print('Таймер дискуссии закончился!');
            _startVotingPhase(); // Переход к фазе голосования
          },
        );
      });
    }
  }

  void _listenToRoom() {
    _roomSubscription = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final playersData = (data['players'] as List<dynamic>?)
                ?.map((e) => Player.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [];
        final winnerMessageData = data['winnerMessage'] as String?;
        final currentPhaseData = data['currentPhase'] as String?;

        setState(() {
          players = playersData;
          winnerMessage = winnerMessageData;
          // Обновляем текущую фазу игры из Firestore
          if (currentPhaseData != null) {
            _currentGamePhase = GamePhase.values.firstWhere(
              (e) => e.name == currentPhaseData,
              orElse: () => GamePhase.discussion, // По умолчанию
            );
          }

          // Проверяем условия окончания игры
          if (winnerMessage != null && !gameOver) {
            gameOver = true; // Устанавливаем флаг, что игра окончена
            _navigateToVictory(); // Переходим на экран победы
            _showPostGameAd(); // Показываем рекламу после игры
          }
        });
      }
    });
  }

  void _listenToLikes() {
    _likesSubscription = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .collection('likes_meta')
        .snapshots()
        .listen((snapshot) {
      // Здесь вы можете обрабатывать изменения в лайках, если нужно
      // Например, обновлять количество лайков у каждого игрока
      // Или получать список лайкнутых игроков
    });
  }

  // --- Методы для логики игры и UI ---

  void _startVotingPhase() {
    if (!mounted) return;

    setState(() {
      _currentGamePhase = GamePhase.voting; // Устанавливаем фазу голосования
      final int _votingTime = 60; // Время для голосования
      _timerController.start(
        _votingTime,
        () {
          print('Таймер голосования закончился!');
          _processVotesAndShowResults(); // Метод для обработки голосов
        },
      );
      // Обновляем состояние комнаты в Firestore
      FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomCode)
          .update({'currentPhase': _currentGamePhase.name});
    });
  }

  void _processVotesAndShowResults() {
    if (!mounted) return;
    setState(() {
      _currentGamePhase = GamePhase.results; // Переход к фазе результатов
    });
    // Здесь должна быть логика подсчета голосов,
    // определение, кто выбыл, или кто победил (если это конец игры)
    // И затем, возможно, вызов _showVoteResultsDialog();
    _showVoteResultsDialog(); // Предположим, что он показывает результаты голосования
  }

  // Обновленный метод для перехода на экран победы (Исправление ошибок 5 и 6)
  void _navigateToVictory() {
    if (winnerMessage != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VictoryScreen(
            // winnerTeam должен быть "mafia" или "villagers"
            // Здесь предполагается, что winnerMessage содержит текст,
            // по которому можно определить команду.
            winnerTeam:
                winnerMessage!.contains('Мафия') ? 'mafia' : 'villagers',
            message: winnerMessage!, // Передаем полное сообщение
            onPlayAgain: () {
              // Логика для перезапуска игры или возврата в лобби
              Navigator.of(context).pop(); // Закрывает VictoryScreen
              // Дополнительная логика: сброс состояния игры, переход к LobbyScreen и т.д.
              // Пример: Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => LobbyScreen()));
            },
          ),
        ),
      );
    }
  }

  void _showPostGameAd() {
    if (gameOver && !_adShown && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return PostGameAdBanner(
            onContinue: () {
              Navigator.of(context).pop();
              setState(() {
                _adShown = true;
              });
            },
          );
        },
      );
    }
  }

  // --- Методы для лайков ---

  Future<String?> _getLikedPlayerName() async {
    final doc = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .collection('likes_meta')
        .doc(widget.playerName)
        .get();
    if (doc.exists && doc.data()!.containsKey('liked')) {
      return doc.data()!['liked'] as String;
    }
    return null;
  }

  void _checkInitialLikeStatus() async {
    _likedPlayer = await _getLikedPlayerName();
    if (mounted) setState(() {});
  }

  void _submitLike(String targetPlayerName) async {
    if (_likedPlayer != null) {
      // Пользователь уже лайкнул кого-то, не позволяем лайкать снова
      return;
    }

    final likesMetaRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .collection('likes_meta');

    await likesMetaRef.doc(widget.playerName).set({
      'liked': targetPlayerName,
    });

    setState(() {
      _likedPlayer = targetPlayerName;
    });

    // Опционально: обновить рейтинг игрока
    await RatingService.updatePlayerRating(
        targetPlayerName, 1); // +1 к рейтингу
  }

  // --- Методы для ботов (без изменений в логике, но убраны предупреждения unused_element) ---
  // (Ошибки unused_element не будут здесь, если эти методы вызываются в вашей игре)

  Player _selectMafiaTarget(List<Player> alivePlayers) {
    // Выбираем случайного мирного жителя
    final villagers =
        alivePlayers.where((p) => p.role == Role.villager && !p.isBot).toList();
    if (villagers.isNotEmpty) {
      villagers.shuffle();
      return villagers.first;
    }
    // Если нет мирных жителей, выбираем любого живого не-мафиози
    final nonMafia =
        alivePlayers.where((p) => p.role != Role.mafia && !p.isBot).toList();
    if (nonMafia.isNotEmpty) {
      nonMafia.shuffle();
      return nonMafia.first;
    }
    // В крайнем случае, просто случайный игрок
    alivePlayers.shuffle();
    return alivePlayers.first;
  }

  Player _selectDoctorTarget(List<Player> alivePlayers) {
    // Врач не может лечить себя, если он не является ботом.
    // Если врач бот, он может лечить себя
    // Если игра начинается, врач лечит случайно выбранного игрока,
    // который не мафия, не себя.
    // Если gamesPlayed == 0, то врач лечит только себя.
    // Если доктор бот, то он лечит себя
    // Если gamesPlayed == 0, то доктор лечит себя
    final doctor = alivePlayers.firstWhere((p) => p.role == Role.doctor);
    if (players.firstWhere((p) => p.name == widget.playerName).isBot) {
      return doctor;
    }
    // Случайный мирный житель или себя, если это первая игра.
    // Для более умного бота нужно реализовать более сложную логику
    alivePlayers.shuffle();
    return alivePlayers.first;
  }

  Player _selectDetectiveTarget(List<Player> alivePlayers) {
    // Детектив выбирает случайного игрока для проверки
    final nonDetective = alivePlayers
        .where((p) => p.role != Role.detective && !p.isBot)
        .toList();
    if (nonDetective.isNotEmpty) {
      nonDetective.shuffle();
      return nonDetective.first;
    }
    // В крайнем случае, просто случайный игрок
    alivePlayers.shuffle();
    return alivePlayers.first;
  }

  Player _selectManiacTarget(List<Player> alivePlayers) {
    // Маньяк выбирает случайного игрока для убийства
    final nonManiac =
        alivePlayers.where((p) => p.role != Role.maniac && !p.isBot).toList();
    if (nonManiac.isNotEmpty) {
      nonManiac.shuffle();
      return nonManiac.first;
    }
    // В крайнем случае, просто случайный игрок
    alivePlayers.shuffle();
    return alivePlayers.first;
  }

  Player _selectVoteTarget(List<Player> alivePlayers) {
    // Выбираем случайного игрока для голосования (для ботов)
    alivePlayers.shuffle();
    return alivePlayers.first;
  }

  void _showVoteResults() {
    // Логика отображения результатов голосования
    // Например, обновить UI, показать диалог
    _showVoteResultsDialog();
    // _startNightPhase(); // продолжение игры - этот метод не определен в текущем коде
  }

  void _showVoteResultsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Результаты голосования'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: voteResults.entries.map((entry) {
                return Text('${entry.key}: ${entry.value}');
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('ОК'),
            ),
          ],
        );
      },
    );
  }

  // --- UI Build Method ---

  @override
  Widget build(BuildContext context) {
    // Определение текущего игрока
    final currentPlayer = players.firstWhere(
      (p) => p.name == widget.playerName,
      orElse: () =>
          Player(name: widget.playerName, role: Role.villager), // Заглушка
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Комната: ${widget.roomCode} - ${currentPlayer.role.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.video_call),
            onPressed: () {
              // Исправление ошибки 8: roomCode вместо roomId
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VideoCallScreen(
                  roomCode: widget.roomCode, // Исправлено
                  playerName: widget.playerName,
                ),
              ));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Таймер
          ListenableBuilder(
            listenable: _timerController,
            builder: (BuildContext context, Widget? child) {
              return Text(
                'Время до конца ${_currentGamePhase.name}: ${_timerController.timeLeft} сек',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              );
            },
          ),
          // Список игроков
          Expanded(
            child: ListView.builder(
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                return ListTile(
                  title: Text(
                    player.name,
                    style: TextStyle(
                      color: player.isAlive ? Colors.black : Colors.grey,
                      decoration: player.isAlive
                          ? TextDecoration.none
                          : TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Text(
                    player.isBot ? 'Бот' : player.role.name,
                    style: TextStyle(
                      color: player.isAlive ? Colors.black54 : Colors.grey,
                    ),
                  ),
                  trailing: player.name == widget.playerName
                      ? const Text('Вы')
                      : null,
                );
              },
            ),
          ),
          // Поле для чата и кнопка отправки
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ChatService.messageController,
                    decoration: const InputDecoration(
                      // Добавлено const
                      labelText: 'Сообщение',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send), // Добавлено const
                  onPressed: () {
                    ChatService.sendMessage(widget.roomCode,
                        widget.playerName); // Вызов sendMessage
                  },
                ),
              ],
            ),
          ),
          // Лайки игроков (если игра еще не окончена)
          if (!gameOver) // Проверяем, что игра не окончена, прежде чем показывать кнопки лайков
            Column(
              children: players
                  .where((p) => p.name != widget.playerName)
                  .map((p) => ListTile(
                        title: Text(p.name),
                        trailing: (_likedPlayer ==
                                null) // Проверка, лайкнул ли текущий пользователь
                            ? IconButton(
                                icon: const Icon(Icons.thumb_up,
                                    color: Colors.green), // Добавлено const
                                onPressed: () => _submitLike(p.name),
                              )
                            : null, // Если уже лайкнул, то кнопка не отображается
                      ))
                  .toList(),
            ),
          // Лучший игрок (если есть данные рейтинга)
          if (ratings.isNotEmpty)
            Text('👑 Лучший игрок: ${bestPlayer ?? 'Нет'}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
