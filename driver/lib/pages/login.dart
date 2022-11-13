
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';



class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {

  checkPermission() async{
    
    if (await Permission.contacts.request().isGranted) {
      return;
}

// You can request multiple permissions at once.
Map<Permission, PermissionStatus> statuses = await [
  Permission.location,
].request();
print(statuses[Permission.location]);
  

    if(await Permission.location.isPermanentlyDenied){
      openAppSettings();
    }
  }

  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: TextButton(
            onPressed: () async {
              checkPermission();
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
