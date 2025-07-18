import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBtOc4El8Y4hlQRbatwd8RgV1pBzgfFA7k',
    appId: '1:678632726327:web:8e057192cfdf27b5a804b2',
    messagingSenderId: '678632726327',
    projectId: 'mafia-meeting-9705b',
    authDomain: 'mafia-meeting-9705b.firebaseapp.com',
    storageBucket: 'mafia-meeting-9705b.firebasestorage.app',
    measurementId: 'G-0EF9WRDGBZ',
    databaseURL:
        'https://mafia-meeting-9705b-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDgZ_w-d995eOy3QB0oBFpGnvpMOjQLhSY',
    appId: '1:678632726327:android:68a828a234faa104a804b2',
    messagingSenderId: '678632726327',
    projectId: 'mafia-meeting-9705b',
    storageBucket: 'mafia-meeting-9705b.firebasestorage.app',
    databaseURL:
        'https://mafia-meeting-9705b-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDfeYleSNMNzkRnx2LTZjpAq3SFas3Ss44',
    appId: '1:678632726327:ios:7b1e76e70272e6bca804b2',
    messagingSenderId: '678632726327',
    projectId: 'mafia-meeting-9705b',
    storageBucket: 'mafia-meeting-9705b.firebasestorage.app',
    iosBundleId: 'com.example.mafiaMeeting',
    databaseURL:
        'https://mafia-meeting-9705b-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDfeYleSNMNzkRnx2LTZjpAq3SFas3Ss44',
    appId: '1:678632726327:ios:7b1e76e70272e6bca804b2',
    messagingSenderId: '678632726327',
    projectId: 'mafia-meeting-9705b',
    storageBucket: 'mafia-meeting-9705b.firebasestorage.app',
    iosBundleId: 'com.example.mafiaMeeting',
    databaseURL:
        'https://mafia-meeting-9705b-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBtOc4El8Y4hlQRbatwd8RgV1pBzgfFA7k',
    appId: '1:678632726327:web:203bf991ca9d86eea804b2',
    messagingSenderId: '678632726327',
    projectId: 'mafia-meeting-9705b',
    authDomain: 'mafia-meeting-9705b.firebaseapp.com',
    storageBucket: 'mafia-meeting-9705b.firebasestorage.app',
    measurementId: 'G-K6ZXJSQ92N',
    databaseURL:
        'https://mafia-meeting-9705b-default-rtdb.europe-west1.firebasedatabase.app',
  );
}
