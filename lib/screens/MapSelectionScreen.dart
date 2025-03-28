import 'dart:async';
import 'dart:math';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:mappls_gl/mappls_gl.dart';
import 'package:geolocator/geolocator.dart';
import '../core/session.dart';
import '../utils/appColors.dart';
import '../widget/customSnackbar.dart';

class MapSelectionScreen extends StatefulWidget {
  const MapSelectionScreen({super.key});

  @override
  _MapSelectionScreenState createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  MapplsMapController? _mapController;
  LatLng? _selectedLocation;
  LatLng? _userLocation;
  final TextEditingController _searchController = TextEditingController();
  bool _isLocationEnabled = false;
  Symbol? _userSymbol;
  Symbol? _selectedSymbol;
  Position? _lastKnown;
  late Future<LatLng> _initialTargetFuture;

  @override
  void initState() {
    super.initState();
    _initialTargetFuture = Session().getUserLastLocation();
  }

  /// Initialize User Location
  Future<void> _initializeLocation() async {
    if (!await _checkAndRequestPermissions()) return;

    _lastKnown = await Geolocator.getLastKnownPosition();
    if (_lastKnown != null) {
      _updateUserLocation(LatLng(_lastKnown!.latitude, _lastKnown!.longitude));
    }
  }

  Future<void> _openNetworkSettings() async {
    const intent = AndroidIntent(
      action: "android.settings.AIRPLANE_MODE_SETTINGS",
    );
    await intent.launch();
  }

  Future<void> _openAppInfo() async {
    const intent = AndroidIntent(
      action: "android.settings.APPLICATION_DETAILS_SETTINGS",
      package: 'com.example.spherelink',
      data: 'package:com.example.spherelink',
    );
    await intent.launch();
  }

  Future<bool> _checkAndRequestPermissions() async {
    bool internet = await InternetConnection().hasInternetAccess;
    if (!internet) {
      showCustomSnackBar(
          context,
          AppColors.textColorPrimary,
          "Internet connection is required.",
          Colors.white,
          "Settings",
          _openNetworkSettings);
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        showCustomSnackBar(
          context,
          AppColors.textColorPrimary,
          "Location permission denied.",
          Colors.white,
          "",
          () {},
        );
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      showCustomSnackBar(
        context,
        AppColors.textColorPrimary,
        "Location permission denied.",
        Colors.white,
        "Settings",
        _openAppInfo,
      );
      return false;
    }
    return true;
  }

  /// Fetch Current Location
  Future<void> _fetchCurrentLocation() async {
    if (!await _checkAndRequestPermissions()) return;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black12,
        builder: (BuildContext context) {
          return const Center(
              child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              color: Colors.blue,
              strokeWidth: 3,
            ),
          ));
        },
      );
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      LatLng newLocation = LatLng(position.latitude, position.longitude);

      if (_userLocation == null ||
          _calculateDistance(_userLocation!, newLocation) > 5) {
        _updateUserLocation(newLocation);
      }
      Navigator.pop(context);
    } catch (e) {
      Navigator.pop(context);
      debugPrint("Error fetching location: $e");
    }
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    return Geolocator.distanceBetween(
        p1.latitude, p1.longitude, p2.latitude, p2.longitude);
  }

  /// Update User Location
  void _updateUserLocation(LatLng location) {
    if (!mounted) return;

    setState(() {
      _userLocation = location;
      _isLocationEnabled = true;
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLng(location),
      duration: const Duration(milliseconds: 500),
    );

    _updateUserSymbol(location);
  }

  /// Update User Symbol on Map
  Future<void> _updateUserSymbol(LatLng location) async {
    if (_mapController == null) return;

    if (_userSymbol == null) {
      _userSymbol = await _mapController!.addSymbol(
        SymbolOptions(
          geometry: location,
          iconSize: 0,
          textField: "You are here",
          textOffset: const Offset(0, 2),
          textSize: 12,
          textColor: "#000000",
        ),
      );
    } else {
      _mapController!.updateSymbol(
        _userSymbol!,
        SymbolOptions(geometry: location),
      );
    }
    _mapController?.easeCamera(CameraUpdate.zoomIn());
  }

  /// Add Selected Location Symbol
  Future<void> _addSelectedLocationSymbol() async {
    if (_mapController == null || _selectedLocation == null) return;

    if (_selectedSymbol == null) {
      _selectedSymbol = await _mapController!.addSymbol(
        SymbolOptions(
          geometry: _selectedLocation!,
          iconImage: "assets/add_location.png",
          iconSize: 1.1,
          textField: "Selected Location",
          textOffset: const Offset(0, 2),
          textSize: 12,
          textColor: "#000000",
        ),
      );
    } else {
      _mapController!.updateSymbol(
        _selectedSymbol!,
        SymbolOptions(geometry: _selectedLocation!),
      );
    }
  }

  /// Search for a Place (Placeholder)
  Future<void> _searchPlace(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _selectedLocation = const LatLng(28.6139, 77.2090); // Example: Delhi
    });

    _mapController?.animateCamera(CameraUpdate.newLatLng(_selectedLocation!));
    await _addSelectedLocationSymbol();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.appprimaryColor,
        title: const Text("Select Location",
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          /// Map Widget
          FutureBuilder(
              future: _initialTargetFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (snapshot.hasData) {
                  return MapplsMap(
                    compassViewMargins: const Point(16, 72),
                    logoViewMargins: const Point(16, 21),
                    logoViewPosition: LogoViewPosition.topLeft,
                    initialCameraPosition: CameraPosition(
                      target: _userLocation ?? snapshot.data!,
                      zoom: 14.0,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_userLocation == null) {
                          _initializeLocation();
                        }
                      });
                    },
                    onMapClick: (point, coordinates) async {
                      setState(() {
                        _selectedLocation = coordinates;
                        _addSelectedLocationSymbol();
                      });
                    },
                    myLocationEnabled: _isLocationEnabled,
                    myLocationTrackingMode:
                        MyLocationTrackingMode.trackingCompass,
                  );
                } else {
                  return const Center(child: Text(''));
                }
              }),

          /// Search Bar
          Positioned(
            top: 10,
            left: 16,
            right: 16,
            child: Expanded(
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for a place...',
                    hintStyle: const TextStyle(fontSize: 14),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),

          /// Confirm Location Button
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: _selectedLocation == null
                  ? null
                  : () {
                      Navigator.pop(context, {
                        'latitude': _selectedLocation!.latitude,
                        'longitude': _selectedLocation!.longitude,
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textColorPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "Confirm Location",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),

          /// Refresh Location
          Positioned(
              bottom: 100,
              right: 20,
              child: FloatingActionButton(
                shape: CircleBorder(),
                backgroundColor: AppColors.appsecondaryColor,
                onPressed: _fetchCurrentLocation,
                child: _isLocationEnabled
                    ? const Icon(Icons.my_location_rounded,
                        color: Colors.blue) // Centered
                    : const ImageIcon(
                        AssetImage("assets/img_location_question.png"),
                        color: Colors.red,
                      ),
              ))
        ],
      ),
    );
  }
}
