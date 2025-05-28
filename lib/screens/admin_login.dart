
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_screen.dart';
import 'admin_logger.dart';

String hashPassword(String password) {
  return sha256.convert(utf8.encode(password)).toString();
}

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key});

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _autoLogin();
  }

  Future<void> _autoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAdmin = prefs.getString('admin');
    if (savedAdmin != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminScreen()));
    }
  }

  Future<void> _tryLogin() async {
    final name = _nameController.text.trim();
    final pass = _passController.text.trim();

    if (name.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Введите имя и пароль');
      return;
    }

    final doc = await FirebaseFirestore.instance.collection('admins').doc(name).get();
    final hashedInput = hashPassword(pass);

    if (!doc.exists || doc['password'] != hashedInput) {
      setState(() => _error = 'Неверный логин или пароль');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin', name);

    await logAdminAction(name, 'Вход в админ-панель');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AdminScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🔐 Вход для админа')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Имя (ID в админах)'),
            ),
            TextField(
              controller: _passController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Пароль'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _tryLogin,
              child: const Text('Войти'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ]
          ],
        ),
      ),
    );
  }
}