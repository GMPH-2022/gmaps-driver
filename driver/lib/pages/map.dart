import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
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

  TextEditingController _searchController = TextEditingController();
  String? hospitalName = 'Max Healthcare';
  String? time = '34mins';
  String? destination;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver\'s view'),
      ),
      body: Column(
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

          Column(
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
        ],
      ),
    );
  }
}
