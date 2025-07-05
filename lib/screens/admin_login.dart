// admin_login.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_logger.dart';
import 'admin_gate.dart';

class AdminLogin extends StatefulWidget {
  final String currentUserId;

  const AdminLogin({super.key, required this.currentUserId});

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
    final savedAdminEmail = prefs.getString('admin_email');

    if (FirebaseAuth.instance.currentUser != null &&
        FirebaseAuth.instance.currentUser!.email == savedAdminEmail) {
      if (mounted) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => AdminGate(
                    currentUserId: FirebaseAuth.instance.currentUser!.uid)));
      }
    }
  }

  Future<void> _tryLogin() async {
    final email = _nameController.text.trim();
    final pass = _passController.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Введите Email и пароль');
      return;
    }

    setState(() => _error = null);

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_email', email);

      await logAdminAction(userCredential.user!.uid, 'Вход в админ-панель');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  AdminGate(currentUserId: userCredential.user!.uid)),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          _error = 'Неверный Email или пароль';
        } else if (e.code == 'invalid-email') {
          _error = 'Некорректный формат Email';
        } else {
          _error = 'Ошибка входа: ${e.message}';
          print('FirebaseAuthException: ${e.code} - ${e.message}');
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Произошла непредвиденная ошибка: $e';
        print('Непредвиденная ошибка при входе: $e');
      });
    }
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
              decoration: const InputDecoration(labelText: 'Email админа'),
              keyboardType: TextInputType.emailAddress,
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
