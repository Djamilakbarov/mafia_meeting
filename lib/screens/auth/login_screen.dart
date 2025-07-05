import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mafia_meeting/screens/auth/phone_auth_screen.dart';
import 'package:mafia_meeting/screens/auth/email_auth_screen.dart';

class LoginScreen extends StatefulWidget {
  // Удалены toggleTheme и isDarkMode из полей класса, так как они не нужны здесь
  // final Future<void> Function(bool) toggleTheme;
  // final bool isDarkMode;

  const LoginScreen({
    super.key,
  });

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    final GoogleSignInAuthentication? googleAuth =
        await googleUser?.authentication;

    if (googleAuth?.accessToken != null && googleAuth?.idToken != null) {
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth!.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      if (userCredential.user != null && mounted) {
        // После успешной аутентификации, возвращаемся к корневому маршруту.
        // main.dart сам определит, куда направить пользователя (LobbyScreen или UsernameSetupScreen).
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  void _navigateToPhoneAuth() {
    // При переходе на PhoneAuthScreen, нужно передать toggleTheme и isDarkMode
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => PhoneAuthScreen(
              // toggleTheme: widget.toggleTheme, // Если бы LoginScreen их принимал
              // isDarkMode: widget.isDarkMode, // Если бы LoginScreen их принимал
              )),
    );
  }

  void _navigateToEmailAuth() {
    // При переходе на EmailAuthScreen, нужно передать toggleTheme и isDarkMode
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => EmailAuthScreen(
              // toggleTheme: widget.toggleTheme, // Если бы LoginScreen их принимал
              // isDarkMode: widget.isDarkMode, // Если бы LoginScreen их принимал
              )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _signInWithGoogle,
              child: const Text('Login with Google'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _navigateToPhoneAuth,
              child: const Text('Login with Phone'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _navigateToEmailAuth,
              child: const Text('Login with Email'),
            ),
          ],
        ),
      ),
    );
  }
}
