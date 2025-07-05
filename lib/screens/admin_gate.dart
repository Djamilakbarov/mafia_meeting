import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AdminGate extends StatefulWidget {
  final String currentUserId;

  const AdminGate({super.key, required this.currentUserId});

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  bool? isAdmin;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final loc = AppLocalizations.of(context)!;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(widget.currentUserId)
          .get();

      if (mounted) {
        setState(() {
          isAdmin = doc.exists;
          _errorMessage = null;
        });
      }
    } catch (e) {
      print("Ошибка при проверке статуса админа: $e");
      if (mounted) {
        setState(() {
          isAdmin = false;
          _errorMessage = loc.adminCheckError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    if (isAdmin == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(loc.checkingAdminStatus),
            ],
          ),
        ),
      );
    }

    if (isAdmin!) {
      return const AdminScreen();
    }

    return Scaffold(
      appBar: AppBar(title: Text(loc.adminAccess)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage ?? loc.noAdminAccess,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.red),
            ),
            if (_errorMessage == null) const Text('⛔')
          ],
        ),
      ),
    );
  }
}
