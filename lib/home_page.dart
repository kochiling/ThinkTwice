import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'fetch_data.dart';
import 'insert_page.dart';
import 'package:thinktwice/auth_service.dart';
import 'package:thinktwice/login.dart';
import 'package:thinktwice/travel_tips.dart';
import 'package:thinktwice/gemini.dart';

class HomePage extends StatefulWidget{
  const HomePage ({Key? key}): super (key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  final _auth = AuthService();

  goToLogin(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const LoginPage()),
  );

  @override
  Widget build (BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Try ME"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const SizedBox(
              height: 30,
            ),
            const Text(
              'Firebase Realtime Database Series in Flutter 2022',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(
              height: 30,
            ),
            const SizedBox(
              height: 30,
            ),
            MaterialButton(
              onPressed: () async {
                await _auth.signout();
                goToLogin(context);
              },
              child: const Text('Log Out'),
              color: Colors.blue,
              textColor: Colors.white,
              minWidth: 300,
              height: 40,
            ),
            MaterialButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TravelTipsPage()),
                );
              },
              child: const Text('Travel Tips'),
              color: Colors.blue,
              textColor: Colors.white,
              minWidth: 300,
              height: 40,
            ),

          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
          onPressed: (){
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (child) => InsertPage(),
              ),
            );
          },
          child: const Icon(
              Icons.add
          )
      ),

    );
  }
}

