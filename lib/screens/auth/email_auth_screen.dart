import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import '../lobby_screen.dart'; // Этот импорт больше не нужен, так как LobbyScreen не используется напрямую

class EmailAuthScreen extends StatefulWidget {
  // Удалены toggleTheme и isDarkMode из полей класса, так как они не нужны здесь
  // final Future<void> Function(bool) toggleTheme;
  // final bool isDarkMode;

  const EmailAuthScreen({
    super.key,
    // Удалены toggleTheme и isDarkMode из конструктора
    // required this.toggleTheme,
    // required this.isDarkMode,
  });

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (userCredential.user != null && mounted) {
        // После успешной аутентификации, возвращаемся к корневому маршруту.
        // main.dart сам определит, куда направить пользователя.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'Login failed');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (userCredential.user != null && mounted) {
        // После успешной аутентификации, возвращаемся к корневому маршруту.
        // main.dart сам определит, куда направить пользователя.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'Registration failed');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Email Authentication')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (_errorMessage.isNotEmpty)
              Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _signIn,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Sign In'),
            ),
            TextButton(
              onPressed: _isLoading ? null : _signUp,
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }
}
