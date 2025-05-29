import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'fetch_data.dart';
import 'insert_page.dart';
import 'package:thinktwice/auth_service.dart';
import 'package:thinktwice/login.dart';

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
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text("Think Twice"),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
      
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
      
      ),
    );
  }
}

