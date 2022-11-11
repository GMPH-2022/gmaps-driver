import 'dart:convert';
import 'dart:ffi';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/pages/place_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart';
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
  bool keepCurrentCenter = true;
  final LatLng _center = const LatLng(28.704, 77.1025);

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
  void dispose() {
    mapController.dispose();
  }

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

      // ignore: todo
      //TODO: Uncomment this
      // driver
      //     .doc('ZEgtVLroHxrTHGLcNnud')
      //     .update(data)
      //     .then((value) => Fluttertoast.showToast(msg: 'updated'));

      sourceLatLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = position;
        speed = ((position.speed * 18) / 5).toStringAsFixed(2);
        _getAddressFromLatLng(_currentPosition!);

        //Keeps current position at the center
        if (keepCurrentCenter) {
          mapController.animateCamera(CameraUpdate.newLatLngZoom(
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              15));
        }
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
        _currrentController.text = _currentAddress!;
      });
    }).catchError((e) {
      debugPrint(e.toString());
    });
  }

  String hospitalName = '';
  String time = '';
  String destinationName = '';
  String destinationId = '';
  late LatLng sourceLatLng;
  late LatLng destinationLatLng;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _currrentController = TextEditingController();

  //when List is zero, it wont render the Listview.builder
  List<String> results = [];
  List<String> resultsPlaceId = [];

  @override
  Widget build(BuildContext context) {
    PlaceApiProvider placeApiProvider = PlaceApiProvider(const Uuid().v4());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver\'s view'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    results.clear();
                    setState(() {});
                  },
                  child: GoogleMap(
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: CameraPosition(
                      target: _center,
                      // target: LatLng(_currentPosition!.latitude,
                      //     _currentPosition!.longitude),
                      zoom: 16.0,
                      // tilt: 3
                    ),
                  ),
                ),
              ),
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Hospital: $hospitalName'),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Time: $time'),
                          ),
                        ),
                      ],
                    ),
                    Row(),
                    TextButton(
                      onPressed: () {
                        Fluttertoast.showToast(msg: 'Navigation started');
                        keepCurrentCenter = false;
                        void sendRequest() async {
                          LatLng destination = destinationLatLng;
                          Response response =
                              await placeApiProvider.getRouteCoordinates(
                                  sourceLatLng, destinationLatLng);
                          String route = jsonDecode(response.body)["routes"][0]
                              ["overview_polyline"]["points"];
                          LatLng southwest = LatLng(
                              jsonDecode(response.body)["routes"][0]["bounds"]
                                  ["southwest"]["lat"],
                              jsonDecode(response.body)["routes"][0]["bounds"]
                                  ["southwest"]["lng"]);
                          LatLng northeast = LatLng(
                              jsonDecode(response.body)["routes"][0]["bounds"]
                                  ["northeast"]["lat"],
                              jsonDecode(response.body)["routes"][0]["bounds"]
                                  ["northeast"]["lng"]);
                          placeApiProvider.createRoute(route); //, sourceLatLng.toString());
                          mapController.animateCamera(
                              CameraUpdate.newLatLngBounds(
                                  LatLngBounds(
                                      southwest: southwest,
                                      northeast: northeast),
                                  10.0));
                        }
                      },
                      child: const Text('Start'),
                    )
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            left: 0,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 3),
                    child: TextField(
                      controller: _currrentController,
                      enabled: false,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) async {
                              if (value == '') {
                                setState(() {
                                  results.clear();
                                });
                                return;
                              }
                              // API calls from here
                              var res = await placeApiProvider
                                  .fetchSuggestions(value);
                              results = res.map((e) => e.description).toList();
                              resultsPlaceId =
                                  res.map((e) => e.placeId).toList();
                            },
                            decoration: const InputDecoration(
                              hintText: "Enter Location",
                            ),
                            onTap: () async {
                              var res = await placeApiProvider
                                  .fetchSuggestions(_searchController.text);
                              results = res.map((e) => e.description).toList();
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _searchController.clear();
                            FocusManager.instance.primaryFocus?.unfocus();
                            // setState(() {
                            results.clear();
                            // });
                          },
                          icon: const Icon(Icons.clear),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  results.length != 0
                      ? Container(
                          color: Colors.white,
                          height: 150,
                          child: ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (context, index) => ListTile(
                              title: Column(
                                children: [
                                  Center(
                                      child: Text(results[index].toString())),
                                  Divider(),
                                ],
                              ),
                              onTap: () async {
                                _searchController.text =
                                    results[index].toString();
                                FocusManager.instance.primaryFocus?.unfocus();
                                destinationId = resultsPlaceId[index];
                                Fluttertoast.showToast(msg: destinationId);
                                if (await placeApiProvider
                                        .getLatLng(destinationId) ==
                                    null) {
                                  Fluttertoast.showToast(
                                      msg: 'No location found');
                                  results.clear();
                                  return;
                                }
                                destinationLatLng = await placeApiProvider.getLatLng(destinationId);
                                debugPrint('destinationLatLng' + destinationLatLng.toString());

                                results.clear();
                                setState(() {});
                                // Fluttertoast.showToast(
                                //     msg: 'destinationId' + destinationId);
                                // debugPrint('destinationId'+destinationId);
                                // debugPrint('destinationLatLng' + destinationLatLng.toString());
                              },
                            ),
                          ),
                        )
                      : Center(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
