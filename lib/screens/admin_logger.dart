
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> logAdminAction(String adminName, String action) async {
  await FirebaseFirestore.instance.collection('admin_logs').add({
    'admin': adminName,
    'action': action,
    'time': Timestamp.now(),
  });
}