import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class MyDatabaseService {
  static final FirebaseDatabase db = FirebaseDatabase.instanceFor(
    app: Firebase.app(), // Get the default initialized app
    databaseURL: 'https://thinktwice-clzy-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
}
