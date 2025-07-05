import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import '../lobby_screen.dart'; // Этот импорт больше не нужен, так как LobbyScreen не используется напрямую

class PhoneAuthScreen extends StatefulWidget {
  // Удалены toggleTheme и isDarkMode из полей класса, так как они не нужны здесь
  // final Future<void> Function(bool) toggleTheme;
  // final bool isDarkMode;

  const PhoneAuthScreen({
    super.key,
    // Удалены toggleTheme и isDarkMode из конструктора
    // required this.toggleTheme,
    // required this.isDarkMode,
  });

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  String _verificationId = '';
  bool _codeSent = false;
  bool _isLoading = false;

  Future<void> _verifyPhoneNumber() async {
    setState(() => _isLoading = true);

    await _auth.verifyPhoneNumber(
      phoneNumber: _phoneController.text,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        UserCredential userCredential =
            await _auth.signInWithCredential(credential);
        if (userCredential.user != null && mounted) {
          // После успешной аутентификации, возвращаемся к корневому маршруту.
          // main.dart сам определит, куда направить пользователя.
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: ${e.message}')),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _codeSent = true;
          _isLoading = false;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _signInWithCode() async {
    setState(() => _isLoading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _codeController.text,
      );
      UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      if (userCredential.user != null && mounted) {
        // После успешной аутентификации, возвращаемся к корневому маршруту.
        // main.dart сам определит, куда направить пользователя.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('An unexpected error occurred: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phone Authentication')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (!_codeSent) ...[
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyPhoneNumber,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Send Code'),
              ),
            ] else ...[
              TextField(
                controller: _codeController,
                decoration:
                    const InputDecoration(labelText: 'Verification Code'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _signInWithCode,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Verify and Sign In'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
