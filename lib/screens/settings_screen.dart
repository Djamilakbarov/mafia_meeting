import 'profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'admin_login.dart';
// import '../models/player_model.dart'; // Удален, так как не используется напрямую
// import '../models/role_enum.dart'; // Удален, так как не используется напрямую
import 'donate_screen.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final Future<void> Function(bool) onThemeChanged;
  final Function(Locale)? onLocaleChanged;
  final String currentUserId;
  final String playerName;

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    this.onLocaleChanged,
    required this.currentUserId,
    required this.playerName,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _isDark;
  late String _playerName;
  late TextEditingController _nameController;
  late Locale _currentLocale;
  List<Map<String, dynamic>> gameHistory = [];

  // Дополнительно, чтобы получить имена игроков для истории
  Map<String, String> _playerNamesCache = {};

  @override
  void initState() {
    super.initState();
    _isDark = widget.isDarkMode;
    _playerName = widget.playerName;
    _nameController = TextEditingController(text: _playerName);
    _loadCurrentLocale();
    _loadGameHistory();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedLangCode = prefs.getString('locale');
    setState(() {
      _currentLocale = savedLangCode != null
          ? Locale(savedLangCode)
          : AppLocalizations.supportedLocales.first;
    });
  }

  Future<void> _savePlayerName() async {
    final loc = AppLocalizations.of(context)!;
    final String newName = _nameController.text.trim();

    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.usernameCannotBeEmpty)),
      );
      return;
    }
    if (newName.length < 3 || newName.length > 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.usernameLengthError)),
      );
      return;
    }

    try {
      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId);

      // Проверяем, менялось ли имя недавно (например, раз в 24 часа)
      final docSnapshot = await userDocRef.get();
      final lastChangeTimestamp =
          docSnapshot.data()?['last_name_change_timestamp'] as Timestamp?;

      if (lastChangeTimestamp != null) {
        final lastChangeDate = lastChangeTimestamp.toDate();
        final now = DateTime.now();
        final difference = now.difference(lastChangeDate);

        if (difference.inHours < 24) {
          // Ограничение на смену имени раз в 24 часа
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.usernameChangeLimit)),
          );
          return;
        }
      }

      // Проверяем уникальность имени
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isEqualTo: newName)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty &&
          querySnapshot.docs.first.id != widget.currentUserId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.usernameAlreadyTaken)),
        );
        return;
      }

      await userDocRef.set({
        'name': newName,
        'last_name_change_timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _playerName = newName;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.usernameSaved)),
        );
      }
    } catch (e) {
      print("Ошибка при сохранении имени: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.saveUsernameError}: $e')),
        );
      }
    }
  }

  Future<void> _loadGameHistory() async {
    final loc = AppLocalizations.of(context)!;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .collection('history')
          .orderBy('timestamp', descending: true)
          .get();

      // Сброс кэша имен перед загрузкой новой истории
      _playerNamesCache.clear();

      setState(() {
        gameHistory = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'roomCode': data['roomCode'] ?? 'N/A',
            'timestamp': data['timestamp'] ?? Timestamp.now(),
            'won': data['won'] ?? false,
            'role': data['role'] ?? 'villager',
            'likesReceived': data['likesReceived'] ?? 0,
            'isBestPlayer': data['isBestPlayer'] ?? false,
            'eliminatedId': data['eliminatedId'],
            'players': data[
                'players'], // Список игроков в этой конкретной игре (их ID и роли)
            'voteResult': data['voteResult'], // Результаты голосования
          };
        }).toList();
      });

      // Предварительная загрузка имен игроков для кэша
      await _preloadPlayerNamesForHistory();
    } catch (e) {
      print("Ошибка загрузки истории игр: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.errorLoadingHistory}: $e')),
        );
      }
    }
  }

  // Метод для предварительной загрузки имен игроков, участвовавших в истории игр
  Future<void> _preloadPlayerNamesForHistory() async {
    Set<String> playerIdsToFetch = {};
    for (var game in gameHistory) {
      if (game['players'] is List) {
        for (var playerMap in game['players']) {
          if (playerMap is Map && playerMap.containsKey('id')) {
            playerIdsToFetch.add(playerMap['id'] as String);
          }
        }
      }
      if (game.containsKey('eliminatedId') && game['eliminatedId'] != null) {
        playerIdsToFetch.add(game['eliminatedId'] as String);
      }
      // Если есть voterId или votedForId в voteResult
      if (game.containsKey('voteResult') && game['voteResult'] is Map) {
        (game['voteResult'] as Map).forEach((voterId, votedForId) {
          playerIdsToFetch.add(voterId as String);
          if (votedForId != null) {
            playerIdsToFetch.add(votedForId as String);
          }
        });
      }
    }

    // Загружаем имена для всех уникальных ID
    for (String id in playerIdsToFetch) {
      if (!_playerNamesCache.containsKey(id)) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(id)
              .get();
          if (userDoc.exists && userDoc.data() != null) {
            _playerNamesCache[id] = userDoc.data()!['name'] ?? 'Unknown';
          } else {
            _playerNamesCache[id] = 'Unknown';
          }
        } catch (e) {
          print("Ошибка загрузки имени игрока $id: $e");
          _playerNamesCache[id] = 'Unknown';
        }
      }
    }
    if (mounted) setState(() {}); // Чтобы обновить UI после загрузки имен
  }

  // Вспомогательный метод для получения имени игрока по ID из кэша
  String _getPlayerNameFromCache(String playerId, AppLocalizations loc) {
    return _playerNamesCache[playerId] ?? loc.unknownPlayer;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.settings),
        backgroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.personalSettings,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(loc.profile),
              subtitle: Text(loc.viewEditProfile),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      currentUserId: widget.currentUserId,
                      playerName: widget.playerName,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(loc.changeUsername),
              subtitle: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: loc.username,
                  border: const OutlineInputBorder(),
                ),
              ),
              trailing: ElevatedButton(
                onPressed: _savePlayerName,
                child: Text(loc.save),
              ),
            ),
            const Divider(),
            Text(loc.appSettings,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: Text(loc.darkMode),
              trailing: Switch(
                value: _isDark,
                onChanged: (value) {
                  setState(() {
                    _isDark = value;
                  });
                  widget.onThemeChanged(value);
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(loc.language),
              trailing: DropdownButton<Locale>(
                value: _currentLocale,
                onChanged: (Locale? newLocale) {
                  if (newLocale != null) {
                    setState(() {
                      _currentLocale = newLocale;
                    });
                    widget.onLocaleChanged?.call(newLocale);
                  }
                },
                items: AppLocalizations.supportedLocales.map((Locale locale) {
                  String languageName;
                  switch (locale.languageCode) {
                    case 'en':
                      languageName = 'English';
                      break;
                    case 'ru':
                      languageName = 'Русский';
                      break;
                    case 'az':
                      languageName = 'Azərbaycan';
                      break;
                    default:
                      languageName = locale.languageCode;
                      break;
                  }
                  return DropdownMenuItem<Locale>(
                    value: locale,
                    child: Text(languageName),
                  );
                }).toList(),
              ),
            ),
            const Divider(),
            // НОВОЕ: Ссылка на DonateScreen
            ListTile(
              leading: const Icon(Icons.favorite),
              title: Text(loc.supportProject),
              subtitle: Text(loc.supportProjectDescription),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DonateScreen()),
                );
              },
            ),
            const Divider(),
            Text(loc.gameHistory,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            if (gameHistory.isEmpty)
              Center(child: Text(loc.noGameHistory))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: gameHistory.length,
                itemBuilder: (context, index) {
                  final game = gameHistory[index];
                  final DateTime date =
                      (game['timestamp'] as Timestamp).toDate();
                  final String formattedDate =
                      DateFormat('dd.MM.yyyy HH:mm').format(date);
                  final bool won = game['won'] ?? false;
                  final String role = game['role'] ?? 'villager';
                  final String eliminatedPlayerName =
                      game['eliminated'] ?? loc.none;

                  // Получаем имя лучшего игрока из кэша
                  final String bestPlayerNameInHistory =
                      (game['isBestPlayer'] == true &&
                              game.containsKey('userId'))
                          ? _getPlayerNameFromCache(
                              game['userId'] as String, loc)
                          : loc.none;

                  // Отображаем все голоса, если есть
                  final Map<String, dynamic> voteResultRaw =
                      game['voteResult'] ?? {};
                  final voteDetails = voteResultRaw.entries.map((entry) {
                    final voterId = entry.key;
                    final votedForId = entry.value;
                    final voterName = _getPlayerNameFromCache(voterId, loc);
                    final votedForName = votedForId != null
                        ? _getPlayerNameFromCache(votedForId, loc)
                        : loc.none;
                    return '$voterName -> $votedForName';
                  }).join(", ");

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      title: Text(
                          "${loc.room}: ${game['roomCode']} - $formattedDate"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              "${loc.role}: $role | ${loc.result}: ${won ? loc.win : loc.loss}"),
                          Text(
                              "${loc.eliminated}: $eliminatedPlayerName | ${loc.players}: ${(game['players'] is List) ? (game['players'] as List).length : 'N/A'}"),
                          Text("⭐ ${loc.bestPlayer}: $bestPlayerNameInHistory"),
                          if (voteResultRaw.isNotEmpty)
                            Text("${loc.allVotes}: $voteDetails"),
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                                "${loc.likesReceived}: ${game['likesReceived'] ?? 0}"),
                          ),
                        ],
                      ),
                      trailing: (game['isBestPlayer'] == true &&
                              game['userId'] == widget.currentUserId)
                          ? const Text('🏅')
                          : null,
                    ),
                  );
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.security),
              title: Text(loc.adminAccess),
              subtitle: Text(loc.adminAccessDescription),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AdminLogin(
                            currentUserId: widget.currentUserId,
                          )),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
