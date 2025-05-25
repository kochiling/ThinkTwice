import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:thinktwice/home_page.dart';
import 'package:thinktwice/login.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';

// DON'T TOUCH THIS PART THANKS <3
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    name: 'thinktwice-clzy',
    options: FirebaseOptions(
      apiKey: 'AIzaSyAOObuTi3EH-boRpVX6-z5-VGxo8ZLhboQ',
      appId: '1:934677057294:android:03e50675bdd7bae907115f',
      messagingSenderId: '934677057294',
      projectId: 'thinktwice-clzy',
      databaseURL: 'https://thinktwice-clzy-default-rtdb.asia-southeast1.firebasedatabase.app',
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}): super (key: key);

  @override
  State <MyApp> createState() => _MyAppState();
}

class _MyAppState extends State <MyApp>{
  @override
  Widget build (BuildContext context) {
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [
        Locale('en'), // English only
      ],
      localizationsDelegates: const [
      ],
      // change to page you wish to launch first
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // If user is logged in
          if (snapshot.connectionState == ConnectionState.active) {
            final user = snapshot.data;
            if (user == null) {
              return const LoginPage();
            } else {
              return HomePage(); // Go directly to home if already logged in
            }
          }
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
      //home: HomePage(),
    );
  }
}


