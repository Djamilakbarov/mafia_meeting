
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_screen.dart';

class AdminGate extends StatefulWidget {
  final String currentUser;

  const AdminGate({super.key, required this.currentUser});

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  bool? isAdmin;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final doc = await FirebaseFirestore.instance
        .collection('admins')
        .doc(widget.currentUser)
        .get();

    setState(() {
      isAdmin = doc.exists;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isAdmin == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (isAdmin!) {
      return const AdminScreen();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Админ-доступ')),
      body: const Center(
        child: Text('⛔ У вас нет доступа к админ-панели'),
      ),
    );
  }
}