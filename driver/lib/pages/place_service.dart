import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart';

// For storing our result
class Suggestion {
  final String placeId;
  final String description;

  Suggestion(this.placeId, this.description);

  @override
  String toString() {
    return 'Suggestion(description: $description, placeId: $placeId)';
  }
}

class PlaceApiProvider {
  final client = Client();

  PlaceApiProvider(this.sessionToken);

  final sessionToken;

  static const String apiKey = 'AIzaSyAeWGCO4e-w8xR_OohqJwJu45hDk2VqM9Q';

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
    print(lList.toString());
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

  final Set<Polyline> _polyLines = {};
  Set<Polyline> get polyLines => _polyLines;

  void createRoute(String encondedPoly) { //, String latLng) {
    _polyLines.add(Polyline(
        polylineId: PolylineId('1'),
        width: 4,
        points: _convertToLatLng(_decodePoly(encondedPoly)),
        color: Colors.red));
    // _addMarker(destination, "KTHM Collage");
  }

  Future<Response> getRouteCoordinates(LatLng l1, LatLng l2) async {
    String url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${l1.latitude},${l1.longitude}&destination=${l2.latitude},${l2.longitude}&key=$apiKey";
    Response response = await client.get(Uri.parse(url));
    return response;
    Map values = jsonDecode(response.body);
    return values["routes"][0]["overview_polyline"]["points"];
  }

  Future<List<Suggestion>> fetchSuggestions(String input) async {
    String request =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&components=country:in&key=$apiKey&sessiontoken=$sessionToken';
    final response = await client.get(Uri.parse(request));

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (result['status'] == 'OK') {
        // compose suggestions in a list
        return result['predictions']
            .map<Suggestion>((p) => Suggestion(p['place_id'], p['description']))
            .toList();
      }
      if (result['status'] == 'ZERO_RESULTS') {
        return [];
      }
      throw Exception(result['error_message']);
    } else {
      throw Exception('Failed to fetch suggestion');
    }
  }

  Future<dynamic> getLatLng(String resultsPlaceId) async {
    String query = 'https://maps.googleapis.com/maps/api/place/details/json?placeid=$resultsPlaceId&key=$apiKey&session=$sessionToken';
    Response response = await client.get(Uri.parse(query));
    if(response.statusCode == 200){
      final result = json.decode(response.body);
      if(result['status'] == 'OK'){
        return LatLng(result['result']['geometry']['location']['lat'], result['result']['geometry']['location']['lng']);
      }
    }
    // throw Exception(result['error_message']);
    return null;
    // Map result = jsonDecode(response.body);
    // LatLng latLng = LatLng(result['result']['geometry']['location']['lat'], result['geometry']['location']['lat']);
    // return latLng;
  }

  // Future<Place> getPlaceDetailFromId(String placeId) async {
  //   // if you want to get the details of the selected place by place_id
  // }
}
