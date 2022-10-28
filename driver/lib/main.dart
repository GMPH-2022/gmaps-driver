import 'package:driver/pages/home.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(Driver());
}


class Driver extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: <String, WidgetBuilder>{
        "/" : (BuildContext ctx) => Home()
      },
    );
  }
}
