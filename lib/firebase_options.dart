// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyCsAeL5wXLINamwVdkLbOBREOiGO9OOkME',
    appId: '1:934677057294:web:da57ae54cc5e98fb07115f',
    messagingSenderId: '934677057294',
    projectId: 'thinktwice-clzy',
    authDomain: 'thinktwice-clzy.firebaseapp.com',
    storageBucket: 'thinktwice-clzy.firebasestorage.app',
    measurementId: 'G-QL4EZK1GRY',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAOObuTi3EH-boRpVX6-z5-VGxo8ZLhboQ',
    appId: '1:934677057294:android:03e50675bdd7bae907115f',
    messagingSenderId: '934677057294',
    projectId: 'thinktwice-clzy',
    storageBucket: 'thinktwice-clzy.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAqODTK75cj8x9SSADTCkTKzq65eSxA9Og',
    appId: '1:934677057294:ios:115b732518de043407115f',
    messagingSenderId: '934677057294',
    projectId: 'thinktwice-clzy',
    storageBucket: 'thinktwice-clzy.firebasestorage.app',
    iosBundleId: 'com.clzyapp.thinktwice',
  );
}
