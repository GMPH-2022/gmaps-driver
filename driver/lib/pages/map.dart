import 'dart:convert';
import 'dart:ffi';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/locationServices.dart';
import 'package:driver/pages/place_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'addressSearch.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Map extends StatefulWidget {
  const Map({Key? key}) : super(key: key);

  @override
  State<Map> createState() => _MapState();
}

class _MapState extends State<Map> {
  String apiKey = 'AIzaSyAeWGCO4e-w8xR_OohqJwJu45hDk2VqM9Q';

  late GoogleMapController mapController;
  final LatLng _center = const LatLng(28.704, 77.1025);

  Client client = Client();

  bool destinationSet = false;
  bool navigationStarted = false;

  String? sourceAddress;
  String? currentAddress;
  String? destinationAddress;
  String? destinationId;
  Position? currentPosition;
  Position? destinationPosition;

  String timeLeft = '';
  String distanceLeft = '';

  List<int> gridIndex = [];

  // define markers for googlemap
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};

  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  //when List is zero, it wont render the Listview.builder
  List<String> results = [];
  List<String> resultsPlaceId = [];

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

  void createRoute(String encondedPoly) {
    polylines.add(Polyline(
        polylineId: PolylineId('1'),
        width: 6,
        points: _convertToLatLng(_decodePoly(encondedPoly)),
        color: Colors.blue));
  }

  List _decodePoly(String poly) {
    var list = poly.codeUnits;
    List lList = [];
    int index = 0;
    int len = poly.length;
    int c = 0;
    do {
      var shift = 0;
      int result = 0;
      do {
        c = list[index] - 63;
        result |= (c & 0x1F) << (shift * 5);
        index++;
        shift++;
      } while (c >= 32);
      if (result & 1 == 1) {
        result = ~result;
      }
      var result1 = (result >> 1) * 0.00001;
      lList.add(result1);
    } while (index < len);
    for (var i = 2; i < lList.length; i++) lList[i] += lList[i - 2];
    // print(lList.toString());
    return lList;
  }

  List<LatLng> _convertToLatLng(List points) {
    List<LatLng> result = <LatLng>[];
    for (int i = 0; i < points.length; i++) {
      if (i % 2 != 0) {
        result.add(LatLng(points[i - 1], points[i]));
      }
    }
    return result;
  }

  @override
  void dispose() {
    mapController.dispose();
  }

  @override
  void initState() {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    CollectionReference driver = firestore.collection('grid');

    Geolocator.getPositionStream().listen((position) async {
      // 1. keep changing the current address until destination is searched
      // 2. keep changing distanceLeft and timeLeft once destination is searched, take currentPosition into account

      gridIndex =
          LocationServices().gridIndex(position.latitude, position.longitude);

      currentPosition = position;
      speed = ((position.speed * 18) / 5).toStringAsFixed(2);

      if (navigationStarted) {
        var cameraPosition = CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 18,
            bearing: position.heading);
        mapController
            .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));

        List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude, position.longitude);
        Placemark place = placemarks[0];

        currentAddress = "${place.name}, ${place.locality}";

        String query =
            'https://maps.googleapis.com/maps/api/distancematrix/json?origins=$currentAddress&destinations=${destinationAddress}&units=metric&key=$apiKey';
        Response response = await client.get(Uri.parse(query));
        var data = jsonDecode(response.body);
        setState(() {
          timeLeft = data['rows'][0]['elements'][0]['duration']['text'];
          distanceLeft = data['rows'][0]['elements'][0]['distance']['text'];
        });
      }

      if (destinationSet == false) {
        mapController.animateCamera(CameraUpdate.newLatLngZoom(
            LatLng(currentPosition!.latitude, currentPosition!.longitude),
            15.5));

        List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude, position.longitude);
        Placemark place = placemarks[0];

        currentAddress = "${place.name}, ${place.locality}";

        sourceAddress = currentAddress;

        setState(() {
          _sourceController.text = sourceAddress!;
        });
      } else if (destinationSet && !navigationStarted) {}
    });

    Geolocator.getPositionStream().listen((position) async {
      int timestamp = position.timestamp!.millisecondsSinceEpoch;
      if (navigationStarted) {
        var data = {
          'live': {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'speed': position.speed,
            'timestamp': timestamp,
          }
        };

        SharedPreferences prefs = await SharedPreferences.getInstance();
        String driverId = prefs.getString('driverId')!;
        // Fluttertoast.showToast(msg: driverId!);
        // var batch = firestore.batch();
        for (var i = gridIndex[0] - 1; i <= gridIndex[0] + 1; i++) {
          for (var j = gridIndex[1] - 1; j <= gridIndex[1] + 1; j++) {
            driver.doc(i.toString()).collection(j.toString()).doc(driverId).set(data);
          }
        }
        // batch.commit();
      }
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<String> _getCurrAddr(Position position) async {
    List<Placemark> placemarks =
        await placemarkFromCoordinates(position.latitude, position.longitude);
    Placemark place = placemarks[0];
    return place.name!;
  }

  @override
  Widget build(BuildContext context) {
    var sessionToken = const Uuid().v4();
    PlaceApiProvider placeApiProvider = PlaceApiProvider(sessionToken);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver\'s view'),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 110.0),
            child: Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      results.clear();
                      setState(() {});
                    },
                    child: GoogleMap(
                      polylines: Set<Polyline>.of(polylines),
                      markers: Set<Marker>.of(markers),
                      myLocationEnabled: true,
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target: _center,
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
                              child: Text('Distance: $distanceLeft'),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text('Time: $timeLeft'),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: navigationStarted
                                ? Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text('i,j is $gridIndex'),
                                    ),
                                  )
                                : Center(),
                          )
                        ],
                      ),
                      navigationStarted
                          ? TextButton(
                              onPressed: () {
                                setState(() {
                                  navigationStarted = false;
                                });
                                Fluttertoast.showToast(
                                    msg: 'Navigation stopped');
                              },
                              child: const Text('Stop'),
                            )
                          : TextButton(
                              onPressed: () {
                                if (!navigationStarted && destinationSet) {
                                  navigationStarted = true;
                                  setState(() {});
                                }
                                Fluttertoast.showToast(
                                    msg: 'Navigation started');
                              },
                              child: const Text('Start'),
                            ),
                    ],
                  ),
                ),
              ],
            ),
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
                      controller: _sourceController,
                      enabled: false,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _destinationController,
                            enabled: !navigationStarted,
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
                              var res = await placeApiProvider.fetchSuggestions(
                                  _destinationController.text);
                              results = res.map((e) => e.description).toList();
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _destinationController.clear();
                            destinationSet = false;
                            polylines.clear();
                            FocusManager.instance.primaryFocus?.unfocus();
                            results.clear();
                          },
                          icon: const Icon(Icons.clear),
                        ),
                      ],
                    ),
                  ),
                  // const SizedBox(
                  //   height: 10,
                  // ),
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
                                //this wont reset the camera to current location
                                destinationSet = true;

                                //this hides the keyboard
                                FocusManager.instance.primaryFocus?.unfocus();

                                //sets the textfield to the selected location
                                destinationAddress = results[index].toString();
                                _destinationController.text =
                                    destinationAddress!;

                                markers.clear();
                                destinationId = resultsPlaceId[index];
                                String query =
                                    'https://maps.googleapis.com/maps/api/place/details/json?placeid=$destinationId&key=$apiKey&sessiontoken=$sessionToken';

                                Response response =
                                    await client.get(Uri.parse(query));
                                var data = jsonDecode(response.body);
                                var destinationLatLng = LatLng(
                                    data['result']['geometry']['location']
                                        ['lat'],
                                    data['result']['geometry']['location']
                                        ['lng']);
                                markers.add(Marker(
                                  markerId: MarkerId(destinationId!),
                                  position: destinationLatLng,
                                  infoWindow: InfoWindow(
                                    title: results[index].toString(),
                                  ),
                                ));

                                results.clear();

                                setState(() {});

                                query =
                                    "https://maps.googleapis.com/maps/api/directions/json?origin=${currentPosition!.latitude},${currentPosition!.longitude}&destination=${destinationLatLng.latitude},${destinationLatLng.longitude}&key=$apiKey";
                                response = await client.get(Uri.parse(query));
                                data = jsonDecode(response.body);

                                LatLngBounds bounds = LatLngBounds(
                                  southwest: LatLng(
                                      data['routes'][0]['bounds']['southwest']
                                          ['lat'],
                                      data['routes'][0]['bounds']['southwest']
                                          ['lng']),
                                  northeast: LatLng(
                                      data['routes'][0]['bounds']['northeast']
                                          ['lat'],
                                      data['routes'][0]['bounds']['northeast']
                                          ['lng']),
                                );
                                mapController.animateCamera(
                                    CameraUpdate.newLatLngBounds(bounds, 50));

                                //show polylines on map
                                createRoute(data['routes'][0]
                                    ['overview_polyline']['points']);

                                query =
                                    'https://maps.googleapis.com/maps/api/distancematrix/json?origins=$sourceAddress&destinations=${_destinationController.text.toString()}&units=metric&key=AIzaSyAeWGCO4e-w8xR_OohqJwJu45hDk2VqM9Q';
                                response = await client.get(Uri.parse(query));
                                data = jsonDecode(response.body);
                                setState(() {
                                  timeLeft = data['rows'][0]['elements'][0]
                                      ['duration']['text'];
                                  distanceLeft = data['rows'][0]['elements'][0]
                                      ['distance']['text'];
                                });


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
