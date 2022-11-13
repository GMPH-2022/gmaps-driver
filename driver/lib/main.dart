import 'package:driver/pages/login.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:driver/pages/map.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // initialize firebase app
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(Driver());
}


class Driver extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: ThemeMode.system,
      initialRoute: '/login',
      routes: <String, WidgetBuilder>{
        "/map" : (BuildContext ctx) => Map(),
        "/login" : (BuildContext ctx) => Login(),
      },
    );
  }
}
