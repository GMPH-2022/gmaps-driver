import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: TextButton(
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              if(prefs.getString('driverId')==Null){
                prefs.setString('driverId', 'GU94z3FTcg0n');
              } else {
                Navigator.pushNamed(context, '/map');
              }
            },
            child: const Text('Login'),
          ),
        ),
      ],
    );
  }
}
