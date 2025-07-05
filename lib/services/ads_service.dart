import 'package:cloud_firestore/cloud_firestore.dart';

class AdsService {
  final _adsRef = FirebaseFirestore.instance.collection('ads');

  Future<String?> getActiveBannerUrl() async {
    try {
      final snapshot =
          await _adsRef.where('isActive', isEqualTo: true).limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data()['bannerUrl'];
      }
      return null;
    } catch (e) {
      print("Ошибка при получении активного баннера: $e");
      return null;
    }
  }
}
