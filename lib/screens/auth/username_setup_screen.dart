// lib/screens/auth/username_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../lobby_screen.dart'; // Убедитесь, что этот импорт есть
// import 'package:mafia_meeting/main.dart'; // <-- ЭТОТ ИМПОРТ БОЛЬШЕ НЕ НУЖЕН

class UsernameSetupScreen extends StatefulWidget {
  final String userId;
  final Future<void> Function(bool) toggleTheme; // <-- Добавлено
  final bool isDarkMode; // <-- Добавлено

  const UsernameSetupScreen({
    super.key,
    required this.userId,
    required this.toggleTheme, // <-- Добавлено
    required this.isDarkMode, // <-- Добавлено
  });

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _saveUsername() async {
    final loc = AppLocalizations.of(context)!;
    final String username = _usernameController.text.trim();

    if (username.isEmpty) {
      setState(() => _errorMessage = loc.usernameCannotBeEmpty);
      return;
    }
    if (username.length < 3 || username.length > 20) {
      setState(() => _errorMessage = loc.usernameLengthError);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(widget.userId);

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isEqualTo: username)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = loc.usernameAlreadyTaken;
            _isLoading = false;
          });
        }
        return;
      }

      await userDocRef.set({
        'name': username,
        'createdAt': FieldValue.serverTimestamp(),
        'last_name_change_timestamp': FieldValue.serverTimestamp(),
        'gamesPlayed': 0,
        'gamesWon': 0,
        'likesReceived': 0,
        'bestPlayerCount': 0,
        'rating': 0,
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LobbyScreen(
              currentUserId: widget.userId,
              playerName: username,
              toggleTheme: widget.toggleTheme, // <-- Используем из widget
              isDarkMode: widget.isDarkMode, // <-- Используем из widget
            ),
          ),
        );
      }
    } catch (e) {
      print("Ошибка при сохранении имени пользователя: $e");
      if (mounted) {
        setState(() {
          _errorMessage = '${loc.saveUsernameError}: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.setupUsername)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              loc.welcomePleaseEnterUsername,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: loc.username,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _saveUsername(),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _saveUsername,
                    child: Text(loc.saveAndContinue),
                  ),
          ],
        ),
      ),
    );
  }
}
