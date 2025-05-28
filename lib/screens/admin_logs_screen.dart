
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminLogsScreen extends StatelessWidget {
  const AdminLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📜 Логи действий админов')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('admin_logs')
            .orderBy('time', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final logs = snapshot.data!.docs;

          if (logs.isEmpty) {
            return const Center(child: Text('Нет записей'));
          }

          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final data = logs[index].data() as Map<String, dynamic>;
              final admin = data['admin'] ?? 'неизвестен';
              final action = data['action'] ?? 'не указано';
              final time = (data['time'] as Timestamp).toDate();

              return ListTile(
                leading: const Icon(Icons.security),
                title: Text('👤 $admin'),
                subtitle: Text(action),
                trailing: Text('${time.hour}:${time.minute.toString().padLeft(2, '0')}\n${time.day}.${time.month}.${time.year}', textAlign: TextAlign.right),
              );
            },
          );
        },
      ),
    );
  }
}