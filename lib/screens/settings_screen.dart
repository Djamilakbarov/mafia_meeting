import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;
  final Function(Locale) onLocaleChanged;

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.onLocaleChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _isDark;
  late String _playerName;
  late TextEditingController _nameController;
  late Locale _currentLocale;

  @override
  void initState() {
    super.initState();
    _isDark = widget.isDarkMode;
    _nameController = TextEditingController();
    _currentLocale = const Locale('en'); // По умолчанию
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('playerName') ?? "Player";
    final localeCode = prefs.getString('locale') ?? 'en';

    setState(() {
      _playerName = name;
      _nameController.text = name;
      _currentLocale = Locale(localeCode);
    });
  }

  Future<void> _saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('playerName', name);
    setState(() {
      _playerName = name;
    });
  }

  void _changeLanguage(Locale? locale) {
    if (locale == null) return;
    widget.onLocaleChanged(locale);
    setState(() {
      _currentLocale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.lobby),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: loc.player),
            onChanged: (value) => _saveName(value),
          ),
          const SizedBox(height: 30),
          SwitchListTile(
            title: const Text("Тёмная тема"),
            value: _isDark,
            onChanged: (val) {
              setState(() {
                _isDark = val;
              });
              widget.onThemeChanged(val);
            },
          ),
          const Divider(height: 40),
          const Text("Язык:", style: TextStyle(fontWeight: FontWeight.bold)),
          RadioListTile<Locale>(
            title: const Text("Русский"),
            value: const Locale('ru'),
            groupValue: _currentLocale,
            onChanged: _changeLanguage,
          ),
          RadioListTile<Locale>(
            title: const Text("English"),
            value: const Locale('en'),
            groupValue: _currentLocale,
            onChanged: _changeLanguage,
          ),
          RadioListTile<Locale>(
            title: const Text("Azərbaycan"),
            value: const Locale('az'),
            groupValue: _currentLocale,
            onChanged: _changeLanguage,
          ),
        ],
      ),
    );
  }
}
