import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_place_picker/google_maps_place_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:truckdelivery/helper/firebase_storage_helper.dart';
import 'package:truckdelivery/helper/firestore_database_helper.dart';
import 'package:truckdelivery/helper/get_storage_helper.dart';
import 'package:truckdelivery/model/car_rent.dart';
import 'package:truckdelivery/model/furniture.dart';
import 'package:truckdelivery/model/parcel.dart';
import 'package:truckdelivery/model/user_model.dart';

class DeliveryController extends GetxController {
  FirestoreDatabaseHelper _firestoreDatabaseHelper = FirestoreDatabaseHelper.instance;
  GetStorageHelper _getStorageHelper = GetStorageHelper.instance;
  FirebaseStorageHelper _firebaseStorageHelper=FirebaseStorageHelper.instance;
  Future<UserModel?> get currentUser => _getStorageHelper.user();
  TextEditingController orderDetail = TextEditingController();
  TextEditingController mobileNumber = TextEditingController();
  TextEditingController description = TextEditingController();

  PickResult? pickselectedPlace;
  PickResult? dropselectedPlace;
  Position? position;
  bool isCheckedPick = true;
  GoogleMapController? mapController;
  double _originLatitude = 26.48424, _originLongitude = 50.04551;
  double _destLatitude = 26.46423, _destLongitude = 50.06358;
  Map<MarkerId, Marker> markers = {};
  Map<PolylineId, Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();
  String googleAPiKey = 'AIzaSyDeX7maRqimkPJPhvxKEy-uTNyV0IhVzlQ';

  void addMarker() {
    final pickLocation = pickselectedPlace!.geometry!.location;
    final dropLocation = dropselectedPlace!.geometry!.location;
    _originLatitude = pickLocation.lat;
    _originLongitude = pickLocation.lng;
    _destLatitude = dropLocation.lng;
    _destLongitude = dropLocation.lat;

    /// origin marker
    _addMarker(LatLng(_originLatitude, _originLongitude), "origin", BitmapDescriptor.defaultMarker);

    /// destination marker
    _addMarker(LatLng(_destLatitude, _destLongitude), "destination", BitmapDescriptor.defaultMarkerWithHue(90));
    _getPolyline();
    print('ad marlker=======================>');
  }

  void onMapCreated(GoogleMapController controller) async {
    mapController = controller;
  }

  _addMarker(LatLng position, String id, BitmapDescriptor descriptor) {
    MarkerId markerId = MarkerId(id);
    Marker marker = Marker(markerId: markerId, icon: descriptor, position: position);
    markers[markerId] = marker;
  }

  _addPolyLine() {
    PolylineId id = PolylineId("poly");
    Polyline polyline = Polyline(visible: true, polylineId: id, color: Colors.red, points: polylineCoordinates);
    polylines[id] = polyline;
    update();
  }

  _getPolyline() async {
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        googleAPiKey, PointLatLng(_originLatitude, _originLongitude), PointLatLng(_destLatitude, _destLongitude),
        travelMode: TravelMode.driving, wayPoints: [PolylineWayPoint(location: "Sabo, Yaba Lagos Nigeria")]);

    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
      print(polylineCoordinates);
    }
    _addPolyLine();
  }

  getlocation() async {
    position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    // print(position?.latitude);
    // print(position?.longitude);
    // // lat=position?.latitude;
    // // long=position?.longitude;
    // final coordinates = new Coordinates(position!.latitude??37.43296265331129,position!.longitude??-122.08832357078792);
    // var addresses = await Geocoder.local.findAddressesFromCoordinates(coordinates);
    // var first = addresses.first;
    // print("${first.featureName} : ${first.addressLine}");
    update();
  }

  @override
  void onInit() {
    getlocation();
    super.onInit();
  }

  Future<String?> addParcel(int isOutCity) async {
    final user = await currentUser;
    if (user == null) return null;
    final parcel = Parcel.initial(
        creatorId: user.id,
        pickLocationLat: pickselectedPlace!.geometry!.location.lat,
        pickLocationLong: pickselectedPlace!.geometry!.location.lng,
        dropLocationLat: dropselectedPlace!.geometry!.location.lat,
        dropLocationLong: dropselectedPlace!.geometry!.location.lng,
        dropAddress: dropselectedPlace!.formattedAddress.toString(),
        coupon: orderDetail.text,
        amount: 10,
        mobileNumebr: mobileNumber.text,
        paymentMethod: 'paymentMethod',
        isParseOutCity: isOutCity == 0 ? true : false,
        pickAddress: pickselectedPlace!.formattedAddress.toString());
    try {
      final parcelBet = await _firestoreDatabaseHelper.addParcel(parcel);
      if (parcelBet.id.isEmpty) return '';
      mobileNumber.clear();
      return parcelBet.id;
    } catch (_) {
      return null;
    }
  }

  Future<String?> addFurniture(
      int isOutCity, String pickDropdown, String dropDropdown, String catTitle, int numberOfPerson) async {
    final user = await currentUser;
    if (user == null) return null;
    final furniture = Furniture.initial(
        creatorId: user.id,
        pickLocationLat: pickselectedPlace!.geometry!.location.lat,
        pickLocationLong: pickselectedPlace!.geometry!.location.lng,
        dropLocationLat: dropselectedPlace!.geometry!.location.lat,
        dropLocationLong: dropselectedPlace!.geometry!.location.lng,
        dropAddress: dropselectedPlace!.formattedAddress.toString(),
        description: description.text,
        numberOfPerson: numberOfPerson,
        pickDropDownValue: pickDropdown,
        dropDropDownValue: dropDropdown,
        carTitle: catTitle,
        amount: 10,
        mobileNumebr: '123455676',
        paymentMethod: 'paymentMethod',
        isParseOutCity: isOutCity == 3 ? true : false,
        pickAddress: pickselectedPlace!.formattedAddress.toString());
    try {
      final parcelBet = await _firestoreDatabaseHelper.addFurniture(furniture);
      if (parcelBet.id.isEmpty) return '';
      description.clear();
      return parcelBet.id;
    } catch (_) {
      return null;
    }
  }

  Future<String?> addRentCar(int isOutCity, XFile? image, String catTitle, String time, String date) async {
    final user = await currentUser;
    if (user == null) return null;
    final imagePath = image != null ? await _firebaseStorageHelper.uploadImage(File(image.path)) : '';
    if (imagePath == null) return'';


    final rentCar = RentCar.initial(
        creatorId: user.id,
        pickLocationLat: pickselectedPlace!.geometry!.location.lat,
        pickLocationLong: pickselectedPlace!.geometry!.location.lng,
        dropLocationLat: dropselectedPlace!.geometry!.location.lat,
        dropLocationLong: dropselectedPlace!.geometry!.location.lng,
        dropAddress: dropselectedPlace!.formattedAddress.toString(),
        description: description.text,
        time: time,
        date: date,
        amountPerKilo: 10,
        carImage: imagePath,
        carTitle: catTitle,
        amount: 10,
        mobileNumebr: '123455676',
        paymentMethod: 'paymentMethod',
        isParseOutCity: isOutCity == 5 ? true : false,
        pickAddress: pickselectedPlace!.formattedAddress.toString());
    try {
      final parcelBet = await _firestoreDatabaseHelper.addRentCar(rentCar);
      if (parcelBet.id.isEmpty) return '';
      description.clear();
      return parcelBet.id;
    } catch (_) {
      return null;
    }
  }

  @override
  void onClose() {
    orderDetail.clear();
    mobileNumber.clear();
    description.clear();
    super.onClose();
  }
}
