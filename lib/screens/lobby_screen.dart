// lib/screens/lobby_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'waiting_room_screen.dart';
import '../models/player_model.dart';
import '../models/role_enum.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'settings_screen.dart';
import '../main.dart'; // Для MafiaMeetingApp.setLocale
import 'package:mafia_meeting/widgets/google_ad_banner_widget.dart';
import 'dart:async'; // Для Timer
import 'constants/app_colors.dart'; // <--- Импорт AppColors

class LobbyScreen extends StatefulWidget {
  final Future<void> Function(bool) toggleTheme;
  final bool isDarkMode;
  final Function(Locale)? onLocaleChanged;
  final String currentUserId;
  final String playerName;

  const LobbyScreen({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
    this.onLocaleChanged,
    required this.currentUserId,
    required this.playerName,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final TextEditingController _roomCodeController = TextEditingController();
  final TextEditingController _playerNameController = TextEditingController();
  int _nightDuration = 15;
  int _discussionDuration = 30;
  int _votingDuration = 20;
  Locale? _selectedLanguage; // Выбранный язык для комнаты

  @override
  void initState() {
    super.initState();
    _playerNameController.text = widget.playerName;
    _selectedLanguage = AppLocalizations
        .supportedLocales.first; // Устанавливаем язык по умолчанию
  }

  @override
  void dispose() {
    _playerNameController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  Future<void> _savePlayerName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('playerName', name);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .set({
        'name': name,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Ошибка при сохранении имени в Firestore: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения имени: $e')),
        );
      }
    }
  }

  Future<void> _createRoom() async {
    final loc = AppLocalizations.of(context)!;
    final roomCode = _roomCodeController.text.trim();
    final currentName = _playerNameController.text.trim();

    if (roomCode.isEmpty || currentName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.enterNameAndCode)),
      );
      return;
    }
    if (_selectedLanguage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.selectLanguageForRoom)),
      );
      return;
    }

    await _savePlayerName(currentName);

    final roomRef =
        FirebaseFirestore.instance.collection('rooms').doc(roomCode);

    try {
      await roomRef.set({
        'roomCode': roomCode,
        'host': currentName,
        'players': [
          Player(
                  id: widget.currentUserId,
                  name: currentName,
                  role: Role.villager)
              .toMap()
        ],
        'createdAt': FieldValue.serverTimestamp(),
        'gamePhase': 'waiting',
        'roomSettings': {
          'nightDuration': _nightDuration,
          'discussionDuration': _discussionDuration,
          'votingDuration': _votingDuration,
          'language': _selectedLanguage!.languageCode,
        },
        'isStatic': false,
        'status': 'waiting_for_players',
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WaitingRoomScreen(
              roomCode: roomCode,
              playerName: currentName,
              currentUserId: widget.currentUserId,
              toggleTheme: widget.toggleTheme,
              isDarkMode: widget.isDarkMode,
            ),
          ),
        );
      }
    } catch (e) {
      print("Ошибка при создании комнаты: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.createRoomError}: $e')),
        );
      }
    }
  }

  Future<void> _joinRoom(String roomCode) async {
    final loc = AppLocalizations.of(context)!;
    final currentName = _playerNameController.text.trim();

    if (currentName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.enterName)),
      );
      return;
    }

    await _savePlayerName(currentName);

    final roomRef =
        FirebaseFirestore.instance.collection('rooms').doc(roomCode);
    DocumentSnapshot<Map<String, dynamic>> roomDoc;
    try {
      roomDoc = await roomRef.get();
    } catch (e) {
      print("Ошибка при получении комнаты для присоединения: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.joinRoomError}: $e')),
        );
      }
      return;
    }

    if (!roomDoc.exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.invalidRoomCode)),
        );
      }
      return;
    } else {
      final currentPlayersData = roomDoc.data()?['players'];
      List<Player> currentPlayers = [];
      if (currentPlayersData is List) {
        currentPlayers = currentPlayersData
            .map((p) {
              if (p is Map && p.containsKey('id')) {
                return Player.fromMap(p as Map<String, dynamic>);
              }
              return null;
            })
            .whereType<Player>()
            .toList();
      }

      if (currentPlayers.any((p) => p.id == widget.currentUserId)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.alreadyInRoom)),
          );
        }
      } else {
        try {
          await roomRef.update({
            'players': FieldValue.arrayUnion([
              Player(
                      id: widget.currentUserId,
                      name: currentName,
                      role: Role.villager)
                  .toMap()
            ]),
          });
        } catch (e) {
          print("Ошибка при присоединении к комнате: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${loc.addPlayerError}: $e')),
            );
          }
          return;
        }
      }
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WaitingRoomScreen(
            roomCode: roomCode,
            playerName: currentName,
            currentUserId: widget.currentUserId,
            toggleTheme: widget.toggleTheme,
            isDarkMode: widget.isDarkMode,
          ),
        ),
      );
    }
  }

  String _getRoomStatusText(String status, AppLocalizations loc) {
    switch (status) {
      case 'waiting_for_players':
        return loc.statusWaitingForPlayers;
      case 'game_started':
        return loc.statusGameStarted;
      case 'in_progress':
        return loc.statusInProgress;
      case 'game_over':
        return loc.statusGameOver;
      default:
        return loc.statusUnknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => widget.toggleTheme(!widget.isDarkMode),
        backgroundColor: AppColors.accentColor,
        child: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            color: Colors.white),
      ),
      appBar: AppBar(
        title: Text(loc.lobby, style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.appBarColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    currentUserId: widget.currentUserId,
                    playerName: widget.playerName,
                    isDarkMode: widget.isDarkMode,
                    onThemeChanged: widget.toggleTheme,
                    onLocaleChanged: widget.onLocaleChanged ??
                        (locale) {
                          MafiaMeetingApp.setLocale(context, locale);
                        },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/mafia_pattern.png'),
            fit: BoxFit.cover,
            // Использование .withAlpha() вместо .withOpacity() для ColorFilter.mode
            colorFilter: ColorFilter.mode(
              Colors.black.withAlpha(
                  (255 * 0.85).round()), // Использование .withAlpha()
              BlendMode.dstATop,
            ),
            // opacity: 0.15, // Это свойство устарело при наличии colorFilter
            repeat: ImageRepeat.repeat,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.getBackgroundColor(widget.isDarkMode),
              AppColors.getPrimaryGradientColor(widget.isDarkMode),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const GoogleAdBannerWidget(),
              const SizedBox(height: 24),
              Text(loc.createRoom,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextColor(widget.isDarkMode))),
              const SizedBox(height: 8),
              TextField(
                controller: _roomCodeController,
                style:
                    TextStyle(color: AppColors.getTextColor(widget.isDarkMode)),
                decoration: InputDecoration(
                  labelText: loc.roomCode,
                  labelStyle: TextStyle(
                      color:
                          AppColors.getSecondaryTextColor(widget.isDarkMode)),
                  filled: true,
                  fillColor: AppColors.getCardColor(widget.isDarkMode)
                      .withAlpha(
                          (255 * 0.5).round()), // Использование .withAlpha()
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: AppColors.getBorderColor(widget.isDarkMode)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: AppColors.getBorderColor(widget.isDarkMode)
                            .withAlpha((255 * 0.7)
                                .round())), // Использование .withAlpha()
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: AppColors.accentColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _playerNameController,
                style:
                    TextStyle(color: AppColors.getTextColor(widget.isDarkMode)),
                decoration: InputDecoration(
                  labelText: loc.player,
                  labelStyle: TextStyle(
                      color:
                          AppColors.getSecondaryTextColor(widget.isDarkMode)),
                  filled: true,
                  fillColor: AppColors.getCardColor(widget.isDarkMode)
                      .withAlpha(
                          (255 * 0.5).round()), // Использование .withAlpha()
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: AppColors.getBorderColor(widget.isDarkMode)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: AppColors.getBorderColor(widget.isDarkMode)
                            .withAlpha((255 * 0.7)
                                .round())), // Использование .withAlpha()
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: AppColors.accentColor, width: 2),
                  ),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(loc.roomLanguage,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.getTextColor(widget.isDarkMode))),
                  DropdownButton<Locale>(
                    value: _selectedLanguage,
                    dropdownColor: AppColors.getCardColor(widget.isDarkMode),
                    style: TextStyle(
                        color: AppColors.getTextColor(widget.isDarkMode)),
                    iconEnabledColor: AppColors.getTextColor(widget.isDarkMode),
                    onChanged: (Locale? newValue) {
                      setState(() {
                        _selectedLanguage = newValue;
                      });
                    },
                    items:
                        AppLocalizations.supportedLocales.map((Locale locale) {
                      String languageName;
                      switch (locale.languageCode) {
                        case 'en':
                          languageName = loc.langEn;
                          break;
                        case 'ru':
                          languageName = loc.langRu;
                          break;
                        case 'az':
                          languageName = loc.langAz;
                          break;
                        default:
                          languageName = locale.languageCode;
                          break;
                      }
                      return DropdownMenuItem<Locale>(
                        value: locale,
                        child: Text(
                          languageName,
                          style: TextStyle(
                              color: AppColors.getTextColor(widget.isDarkMode)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(loc.phaseTimes,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextColor(widget.isDarkMode))),
              _buildDurationRow(loc.nightTime, _nightDuration,
                  (val) => _nightDuration = val!),
              _buildDurationRow(loc.discussionTime, _discussionDuration,
                  (val) => _discussionDuration = val!),
              _buildDurationRow(loc.votingTime, _votingDuration,
                  (val) => _votingDuration = val!),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _createRoom,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                  shadowColor: AppColors.primaryColor.withAlpha(
                      (255 * 0.5).round()), // Использование .withAlpha()
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: Text(loc.createAndJoin),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => _joinRoom(_roomCodeController.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryButtonColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                  shadowColor: AppColors.secondaryButtonColor.withAlpha(
                      (255 * 0.5).round()), // Использование .withAlpha()
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: Text(loc.joinRoom),
              ),
              const SizedBox(height: 24),
              Text(loc.activeRooms,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextColor(widget.isDarkMode))),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance.collection('rooms').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('${loc.error}: ${snapshot.error}',
                            style: TextStyle(
                                color: AppColors.getTextColor(
                                    widget.isDarkMode))));
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.accentColor));
                  }

                  final rooms = snapshot.data!.docs;
                  if (rooms.isEmpty) {
                    return Center(
                        child: Text(loc.noActiveRooms,
                            style: TextStyle(
                                color: AppColors.getSecondaryTextColor(
                                    widget.isDarkMode))));
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      final roomData =
                          rooms[index].data() as Map<String, dynamic>;
                      final roomCode = roomData['roomCode'] ?? 'N/A';
                      final hostName = roomData['host'] ?? 'N/A';
                      final playerCount =
                          (roomData['players'] as List?)?.length ?? 0;
                      final roomStatus = roomData['status'] ?? 'unknown';
                      final roomLanguage =
                          roomData['roomSettings']?['language'] ?? 'en';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: AppColors.getCardColor(widget.isDarkMode)
                            .withAlpha((255 * 0.8)
                                .round()), // Использование .withAlpha()
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 3,
                        child: ListTile(
                          title: Text(
                              '${loc.room}: $roomCode (${loc.host}: $hostName)',
                              style: TextStyle(
                                  color:
                                      AppColors.getTextColor(widget.isDarkMode),
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${loc.players}: $playerCount | ${loc.status}: ${_getRoomStatusText(roomStatus, loc)} | ${loc.language}: $roomLanguage',
                            style: TextStyle(
                                color: AppColors.getSecondaryTextColor(
                                    widget.isDarkMode)),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _joinRoom(roomCode),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(loc.join),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationRow(
      String label, int currentValue, ValueChanged<int?> onChanged) {
    final loc = AppLocalizations.of(context)!;
    List<int> itemsList;
    if (label == loc.nightTime || label == loc.votingTime) {
      itemsList = [10, 15, 20, 30];
    } else {
      // discussionTime
      itemsList = [20, 30, 45, 60, 120, 180, 240];
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: AppColors.getSecondaryTextColor(widget.isDarkMode))),
        DropdownButton<int>(
          value: currentValue,
          dropdownColor: AppColors.getCardColor(widget.isDarkMode),
          style: TextStyle(color: AppColors.getTextColor(widget.isDarkMode)),
          iconEnabledColor: AppColors.getTextColor(widget.isDarkMode),
          items: itemsList.map((int val) {
            return DropdownMenuItem<int>(
              value: val,
              child: Text(
                '$val ${loc.seconds}',
                style:
                    TextStyle(color: AppColors.getTextColor(widget.isDarkMode)),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
