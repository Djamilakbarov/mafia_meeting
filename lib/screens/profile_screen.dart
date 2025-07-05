import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileScreen extends StatefulWidget {
  final String currentUserId;
  final String playerName;

  const ProfileScreen(
      {super.key, required this.currentUserId, required this.playerName});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _country;
  BannerAd? _bannerAd;
  bool _isLoading = true;
  String? _errorMessage;
  int wins = 0;
  int losses = 0;
  int rating = 0;
  int likesReceived = 0;
  List<Map<String, dynamic>> history = [];
  int bestPlayerCount = 0;
  Map<String, dynamic>? _userData;
  String? _avatarUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _getCountry();
    _loadBanner();
    _loadProfile();
  }

  Future<void> _getCountry() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('Разрешение на местоположение отклонено или запрещено навсегда.');
        if (mounted) {
          setState(() {
            _country = null;
          });
        }
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.low),
      );
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        if (mounted) {
          setState(() {
            _country = placemarks.first.isoCountryCode;
          });
        }
      }
    } catch (e) {
      print('Ошибка определения страны: $e');
      if (mounted) {
        setState(() {
          _country = null;
        });
      }
    }
  }

  void _loadBanner() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-7353499788951001/7486302801',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('Баннер профиля загружен: ${ad.adUnitId}');
          if (mounted) setState(() {});
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Баннер профиля не загрузился: $error');
          ad.dispose();
        },
        onAdOpened: (ad) => debugPrint('Баннер профиля открыт.'),
        onAdClosed: (ad) => debugPrint('Баннер профиля закрыт.'),
        onAdImpression: (ad) => debugPrint('Показ баннера профиля.'),
      ),
    )..load();
  }

  Future<void> _loadProfile() async {
    final loc = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .get();

      if (mounted) {
        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            _userData = data;
            wins = data['gamesWon'] ?? 0;
            losses = (data['gamesPlayed'] ?? 0) - wins;
            rating = data['rating'] ?? 0;
            likesReceived = data['likesReceived'] ?? 0;
            _avatarUrl = data['avatarUrl'];
            _isLoading = false;
          });
          await _loadGameHistory();
        } else {
          setState(() {
            _errorMessage = loc.profileNotFound;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print("Ошибка при загрузке профиля ${widget.currentUserId}: $e");
      if (mounted) {
        setState(() {
          _errorMessage = '${loc.profileLoadError}: $e';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.profileLoadError}: $e')),
        );
      }
    }
  }

  Future<void> _loadGameHistory() async {
    try {
      final historySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .collection('history')
          .orderBy('timestamp', descending: true)
          .get();

      if (mounted) {
        setState(() {
          history = historySnapshot.docs.map((doc) => doc.data()).toList();
          bestPlayerCount =
              history.where((game) => (game['isBestPlayer'] == true)).length;
        });
      }
    } catch (e) {
      print("Ошибка при загрузке истории игр: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при загрузке истории игр: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final loc = AppLocalizations.of(context)!;
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(loc.selectImageSource),
          actions: <Widget>[
            TextButton(
              child: Text(loc.camera),
              onPressed: () => Navigator.pop(context, ImageSource.camera),
            ),
            TextButton(
              child: Text(loc.gallery),
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        );
      },
    );

    if (source != null) {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 500,
        maxHeight: 500,
      );

      if (pickedFile != null) {
        await _uploadAvatar(File(pickedFile.path));
      }
    }
  }

  Future<void> _uploadAvatar(File imageFile) async {
    final loc = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      final userId = widget.currentUserId;

      final String fileExtension = imageFile.path.split('.').last;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('avatars')
          .child(userId)
          .child('$userId.$fileExtension');

      await storageRef.putFile(imageFile);

      final String downloadUrl = await storageRef.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({'avatarUrl': downloadUrl}, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _avatarUrl = downloadUrl;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.avatarUploadSuccess)),
        );
      }
    } catch (e) {
      print("Ошибка при загрузке аватара: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.avatarUploadError}: $e')),
        );
      }
    }
  }

  Future<void> _deleteAvatar() async {
    final loc = AppLocalizations.of(context)!;
    if (_avatarUrl == null) return;

    setState(() => _isLoading = true);
    try {
      final userId = widget.currentUserId;

      final Uri uri = Uri.parse(_avatarUrl!);
      final String fileName = uri.pathSegments.last;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('avatars')
          .child(userId)
          .child(fileName);

      await storageRef.delete();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'avatarUrl': FieldValue.delete()});

      if (mounted) {
        setState(() {
          _avatarUrl = null;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.avatarDeleteSuccess)),
        );
      }
    } catch (e) {
      print("Ошибка при удалении аватара: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.avatarDeleteError}: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final currentLocale = Localizations.localeOf(context);

    return Scaffold(
      bottomNavigationBar: _userData?['isVip'] != true && _bannerAd != null
          ? SizedBox(
              height: _bannerAd!.size.height.toDouble(),
              width: _bannerAd!.size.width.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            )
          : null,
      appBar: AppBar(title: Text('${loc.profile}: ${widget.playerName}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Text(_errorMessage!,
                        style: const TextStyle(color: Colors.red)))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.blueGrey,
                                backgroundImage: _avatarUrl != null
                                    ? CachedNetworkImageProvider(_avatarUrl!)
                                    : null,
                                child: _avatarUrl == null
                                    ? Text(
                                        widget.playerName
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: const TextStyle(
                                            fontSize: 40,
                                            fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _pickImage,
                                  icon: const Icon(Icons.edit),
                                  label: Text(loc.changeAvatar),
                                ),
                                if (_avatarUrl != null) ...[
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    onPressed: _deleteAvatar,
                                    icon: const Icon(Icons.delete),
                                    label: Text(loc.deleteAvatar),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('🏆 ${loc.wins}: $wins'),
                      Text('💀 ${loc.losses}: $losses'),
                      Text('❤️ ${loc.rating}: $rating'),
                      Text('👍 ${loc.likesReceived}: $likesReceived'),
                      Text('👑 ${loc.bestPlayerTitle}: $bestPlayerCount'),
                      if (_country != null)
                        Text('📍 ${loc.country}: $_country'),
                      const SizedBox(height: 16),
                      Text(loc.gameHistory,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: history.isEmpty
                            ? Center(child: Text(loc.noHistoryData))
                            : ListView.builder(
                                itemCount: history.length,
                                itemBuilder: (context, index) {
                                  final game = history[index];
                                  final DateTime gameDate = (game['timestamp']
                                          is Timestamp)
                                      ? (game['timestamp'] as Timestamp)
                                          .toDate()
                                      : DateTime.tryParse(
                                              game['timestamp'] as String? ??
                                                  '') ??
                                          DateTime.now();

                                  final String formattedDate =
                                      currentLocale.languageCode == 'en'
                                          ? DateFormat.yMd()
                                              .add_jm()
                                              .format(gameDate)
                                          : DateFormat('dd.MM.yyyy HH:mm')
                                              .format(gameDate);
                                  final historyPlayerName =
                                      game['playerName'] ?? loc.unknown;

                                  return ListTile(
                                    title: Text(
                                        '${loc.role}: ${game['role']} — ${game['won'] == true ? loc.win : loc.loss}'),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            '${formattedDate} | ${loc.likes}: ${game['likesReceived'] ?? 0} | ${loc.bestPlayerShort}: ${(game['isBestPlayer'] == true) ? "👑" : "-"}'),
                                        if (game['isBestPlayer'] == true)
                                          Text(
                                              '(${loc.bestPlayer}: $historyPlayerName)'),
                                      ],
                                    ),
                                    trailing: (game['isBestPlayer'] == true &&
                                            game['userId'] ==
                                                widget.currentUserId)
                                        ? const Text('🏅')
                                        : null,
                                  );
                                },
                              ),
                      )
                    ],
                  ),
      ),
    );
  }
}
