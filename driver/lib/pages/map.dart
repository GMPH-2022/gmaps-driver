import 'dart:ffi';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'addressSearch.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Map extends StatefulWidget {
  const Map({Key? key}) : super(key: key);

  @override
  State<Map> createState() => _MapState();
}

class _MapState extends State<Map> {
  late GoogleMapController mapController;
  final LatLng _center = const LatLng(9.754, 76.650);

  String? _currentAddress;
  Position? _currentPosition = Position(
      latitude: 9.754,
      longitude: 76.650,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0);
  String speed = '0.0';

  @override
  void initState() {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    CollectionReference driver = firestore.collection('driver');

    Geolocator.getPositionStream().listen((position) {
      var data = {
        'live': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'speed': position.speed,
          'timestamp': position.timestamp,
        }
      };

      driver
          .doc('ZEgtVLroHxrTHGLcNnud')
          .update(data)
          .then((value) => Fluttertoast.showToast(msg: 'updated'));

      setState(() {
        _currentPosition = position;
        speed = ((position.speed * 18) / 5).toStringAsFixed(2);
        _getAddressFromLatLng(_currentPosition!);
      });
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> _getAddressFromLatLng(Position position) async {
    await placemarkFromCoordinates(
            _currentPosition!.latitude, _currentPosition!.longitude)
        .then((List<Placemark> placemarks) {
      Placemark place = placemarks[0];
      setState(() {
        _currentAddress =
            '${place.street}, ${place.subLocality}, ${place.subAdministrativeArea}, ${place.postalCode}';
      });
    }).catchError((e) {
      debugPrint(e);
    });
  }

  String? hospitalName = 'Max Healthcare';
  String? time = '34mins';
  String? destination;

  TextEditingController _searchController = TextEditingController();
  final List<String> entries = <String>['India', 'Africa', 'Japan'];

 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver\'s view'),
      ),
      body: Stack(
        children: [
          Container(
            child: Expanded(
              child: GoogleMap(
                myLocationEnabled: true,
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                      _currentPosition!.latitude, _currentPosition!.longitude),
                  zoom: 16.0,
                  // tilt: 3
                ),
              ),
            ),
          ),
          Positioned(
            // fill position details here
            top: 0,
            right: 0,
            left: 0,
            height: 300,
            child: Container(
              child: 
              Column(
                children: [
                  Row(
                    children: [
                        Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15.0, vertical: 5.0),
                          child: TextFormField(
                            controller: _searchController,
                            onChanged: (value) {},
                            decoration: const InputDecoration(
                              hintText: "Enter Location",
                            ),
                            onTap: () async{
                            },
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          _searchController.clear();
                        },
                        icon: const Icon(Icons.clear),
                      ),
                    ],
                  ),
                  Expanded(
                    child: SizedBox(
                      child: ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: ((context, index) {
                            return Container(
                              height: 50,
                              child: Center(child: Text('Entry ${entries[index]}')),
                            );
                          }
                         )
                        ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            width: 250,
            height: 100,
            child: Container(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                              'Hospital: $hospitalName'),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                              'Time: $time'),
                        ),
                      ),
                    ],
                  ),
                  
                  Row(),
                  TextButton(
                    onPressed: () {
                      Fluttertoast.showToast(msg: 'Navigation started');
                    },
                    child: const Text('Start'),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
