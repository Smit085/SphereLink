import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:mappls_gl/mappls_gl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:spherelink/core/AppConfig.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../core/session.dart';
import '../data/ViewData.dart';
import '../utils/appColors.dart';
import '../widget/customSnackbar.dart';

class ViewMapScreen extends StatefulWidget {
  final ViewData view;
  const ViewMapScreen({super.key, required this.view});

  @override
  _ViewMapScreenState createState() => _ViewMapScreenState();
}

class _ViewMapScreenState extends State<ViewMapScreen> {
  MapplsMapController? _mapController;
  LatLng? _userLocation;
  LatLng? _viewLocation;
  bool _isLocationEnabled = false;
  Symbol? _userSymbol;
  Symbol? _viewSymbol;
  Position? _lastKnown;
  late Future<LatLng> _initialTargetFuture;
  Line? _routeLine;
  bool _useMapplsNavigation = false;
  double? _routeDuration;
  double? _routeDistance;
  bool _isNavigationActive = false;
  List<LatLng> _routeCoordinates = [];
  BuildContext? _scaffoldContext;
  Timer? _locationUpdateTimer;
  bool _showNavigationPanel = false;

  @override
  void initState() {
    super.initState();
    _initialTargetFuture = Session().getUserLastLocation();
    debugPrint("Initial Thumbnail URL: ${widget.view.thumbnailImageUrl}");
    if (widget.view.latitude != null && widget.view.longitude != null) {
      _viewLocation = LatLng(widget.view.latitude!, widget.view.longitude!);
    } else {
      debugPrint(
          "View location is null: latitude=${widget.view.latitude}, longitude=${widget.view.longitude}");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showCustomSnackBar(
          context,
          Colors.red,
          "View location not available.",
          Colors.white,
          "",
          () {},
        );
      });
    }
  }

  Future<void> _initializeLocation() async {
    if (!await _checkAndRequestPermissions()) return;
    try {
      _lastKnown = await Geolocator.getLastKnownPosition();
      if (_lastKnown != null) {
        _updateUserLocation(
            LatLng(_lastKnown!.latitude, _lastKnown!.longitude));
      } else {
        debugPrint("Last known position is null");
      }
    } catch (e) {
      debugPrint("Error initializing location: $e");
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
        showCustomSnackBar(context, AppColors.textColorPrimary,
            "Location permission denied.", Colors.white, "Settings", () {});
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

  Future<void> _fetchCurrentLocation({bool isNavigationUpdate = false}) async {
    if (!await _checkAndRequestPermissions()) return;
    try {
      if (!isNavigationUpdate) {
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
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      LatLng newLocation = LatLng(position.latitude, position.longitude);
      if (_userLocation == null ||
          _calculateDistance(_userLocation!, newLocation) > 5) {
        _updateUserLocation(newLocation);
        if (isNavigationUpdate &&
            _isNavigationActive &&
            _scaffoldContext != null) {
          double distanceMoved = _userLocation != null
              ? _calculateDistance(_userLocation!, newLocation)
              : 0.0;
          if (distanceMoved > 50) {
            debugPrint(
                "User moved significantly ($distanceMoved m), updating route");
            await _fetchAndDisplayRoute(_scaffoldContext!);
          }
        }
      }
      if (!isNavigationUpdate) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!isNavigationUpdate) {
        Navigator.pop(context);
      }
      debugPrint("Error fetching location: $e");
      if (!isNavigationUpdate) {
        showCustomSnackBar(
          context,
          Colors.red,
          "Failed to fetch current location.",
          Colors.white,
          "",
          () {},
        );
      }
    }
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    return Geolocator.distanceBetween(
        p1.latitude, p1.longitude, p2.latitude, p2.longitude);
  }

  void _updateUserLocation(LatLng location) {
    if (!mounted) return;
    if (_routeLine != null && !_isNavigationActive) {
      try {
        _mapController?.removeLine(_routeLine!);
        debugPrint("Cleaned up old route: ${_routeLine!.id}");
      } catch (e) {
        debugPrint("Error cleaning up old route: $e");
      }
    }
    setState(() {
      _userLocation = location;
      _isLocationEnabled = true;
      if (!_isNavigationActive) {
        _routeDuration = null;
        _routeDistance = null;
        _routeCoordinates = [];
      }
    });
    debugPrint("User location updated: $location");
    if (!_isNavigationActive) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(location),
        duration: const Duration(milliseconds: 500),
      );
    }
    _updateUserSymbol(location);
  }

  Future<void> _updateUserSymbol(LatLng location) async {
    if (_mapController == null) {
      debugPrint("Map controller is null, cannot update user symbol");
      return;
    }
    try {
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
      debugPrint("User symbol updated at $location");
    } catch (e) {
      debugPrint("Error updating user symbol: $e");
    }
  }

  Future<void> _addViewLocationSymbolWithThumbnail() async {
    if (_mapController == null || _viewLocation == null) {
      debugPrint(
          "Map controller or view location is null: controller=$_mapController, viewLocation=$_viewLocation");
      return;
    }
    try {
      if (_viewSymbol == null && widget.view.thumbnailImageUrl != null) {
        final response =
            await http.get(Uri.parse(widget.view.thumbnailImageUrl!));
        if (response.statusCode == 200) {
          img.Image? originalImage = img.decodeImage(response.bodyBytes);
          if (originalImage != null) {
            if (originalImage.width < 150 || originalImage.height < 150) {
              debugPrint(
                  "Warning: Source image resolution (${originalImage.width}x${originalImage.height}) is low, may affect thumbnail quality");
            }
            img.Image resizedImage = img.copyResize(
              originalImage,
              width: 150,
              height: 150,
              interpolation: img.Interpolation.cubic,
            );
            img.Image markerImage =
                img.Image(width: 180, height: 180, numChannels: 4);
            img.fill(markerImage, color: img.ColorRgba8(0, 0, 0, 0));
            const int centerX = 90;
            const int centerY = 90;
            const int outerRadius = 90;
            const int innerRadius = 75;
            img.drawCircle(
              markerImage,
              x: centerX,
              y: centerY,
              radius: outerRadius,
              color: img.ColorRgba8(255, 255, 255, 255),
            );
            img.drawCircle(
              markerImage,
              x: centerX,
              y: centerY,
              radius: innerRadius,
              color: img.ColorRgba8(0, 0, 0, 0),
            );
            for (int y = 0; y < resizedImage.height; y++) {
              for (int x = 0; x < resizedImage.width; x++) {
                double distance = sqrt(pow(x - resizedImage.width / 2, 2) +
                    pow(y - resizedImage.height / 2, 2));
                if (distance <= innerRadius) {
                  markerImage.setPixel(
                      x + 15, y + 15, resizedImage.getPixel(x, y));
                } else if (distance <= innerRadius + 2) {
                  var pixel = resizedImage.getPixel(x, y);
                  double alphaFraction = 1 - (distance - innerRadius) / 2;
                  int alpha = (255 * alphaFraction).round();
                  markerImage.setPixel(
                    x + 15,
                    y + 15,
                    img.ColorRgba8(
                      pixel.r.toInt(),
                      pixel.g.toInt(),
                      pixel.b.toInt(),
                      alpha,
                    ),
                  );
                }
              }
            }
            Uint8List customImageBytes =
                Uint8List.fromList(img.encodePng(markerImage, level: 1));
            await _mapController!
                .addImage("custom_thumbnail", customImageBytes);
            _viewSymbol = await _mapController!.addSymbol(
              SymbolOptions(
                geometry: _viewLocation!,
                iconImage: "custom_thumbnail",
                iconSize: 0.8,
                draggable: false,
              ),
            );
            debugPrint(
                "High-quality thumbnail marker added successfully at $_viewLocation");
          } else {
            debugPrint("Failed to decode image");
            _viewSymbol = await _mapController!.addSymbol(
              SymbolOptions(
                geometry: _viewLocation!,
                iconImage: "assets/add_location.png",
                iconSize: 1.0,
              ),
            );
          }
        } else {
          debugPrint(
              "Failed to fetch thumbnail, status code: ${response.statusCode}");
          _viewSymbol = await _mapController!.addSymbol(
            SymbolOptions(
              geometry: _viewLocation!,
              iconImage: "assets/add_location.png",
              iconSize: 1.0,
            ),
          );
        }
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_viewLocation!, 14.0),
          duration: const Duration(milliseconds: 500),
        );
      } else if (_viewSymbol != null) {
        _mapController!.updateSymbol(
          _viewSymbol!,
          SymbolOptions(geometry: _viewLocation!),
        );
      }
    } catch (e) {
      debugPrint("Error in _addViewLocationSymbolWithThumbnail: $e");
      if (_viewSymbol == null) {
        _viewSymbol = await _mapController!.addSymbol(
          SymbolOptions(
            geometry: _viewLocation!,
            iconImage: "assets/add_location.png",
            iconSize: 1.0,
          ),
        );
      }
    }
  }

  Future<void> _fetchAndDisplayRoute(BuildContext sheetContext) async {
    if (_mapController == null ||
        _userLocation == null ||
        _viewLocation == null) {
      debugPrint("Missing map controller or locations");
      showCustomSnackBar(
        context,
        Colors.red,
        "Unable to get directions. Location or map data is missing.",
        Colors.white,
        "",
        () {},
      );
      Navigator.of(sheetContext).pop();
      return;
    }

    if (!_useMapplsNavigation) {
      try {
        final String googleMapsUrl = 'https://www.google.com/maps/dir/?api=1'
            '&origin=${_userLocation!.latitude},${_userLocation!.longitude}'
            '&destination=${_viewLocation!.latitude},${_viewLocation!.longitude}'
            '&travelmode=driving';
        await launchUrl(
          Uri.parse(googleMapsUrl),
          mode: LaunchMode.externalApplication,
        );
        debugPrint("Launched Google Maps for navigation");
        setState(() {
          _routeDuration = null;
          _routeDistance = null;
          _isNavigationActive = false;
          _routeCoordinates = [];
          _showNavigationPanel = false;
        });
        Navigator.of(sheetContext).pop();
        return;
      } catch (e) {
        debugPrint("Error launching Google Maps: $e");
        showCustomSnackBar(
          context,
          Colors.red,
          "Failed to open Google Maps.",
          Colors.white,
          "",
          () {},
        );
        Navigator.of(sheetContext).pop();
        return;
      }
    }

    // Close the bottom sheet immediately for Mappls navigation
    Navigator.of(sheetContext).pop();

    const String apiKey = AppConfig.mapSDKKey;
    if (apiKey.isEmpty) {
      debugPrint("Mappls API key is missing");
      showCustomSnackBar(
        context,
        Colors.red,
        "Mappls API key is missing.",
        Colors.white,
        "",
        () {},
      );
      return;
    }

    final String directionsUrl =
        'https://apis.mappls.com/advancedmaps/v1/$apiKey/route_adv/driving/'
        '${_userLocation!.longitude},${_userLocation!.latitude};'
        '${_viewLocation!.longitude},${_viewLocation!.latitude}?geometries=polyline';

    try {
      debugPrint("Fetching route from: $directionsUrl");
      final response = await http.get(Uri.parse(directionsUrl));
      debugPrint(
          "Directions API response: ${response.statusCode}, body: ${response.body}");

      if (response.statusCode != 200) {
        debugPrint(
            "Failed to fetch route: ${response.statusCode} - ${response.reasonPhrase}");
        showCustomSnackBar(
          context,
          Colors.red,
          "Failed to fetch route: ${response.statusCode}",
          Colors.white,
          "",
          () {},
        );
        return;
      }

      dynamic data;
      try {
        data = json.decode(response.body);
        if (data is! Map<String, dynamic>) {
          throw FormatException("Invalid JSON format: Expected a Map");
        }
      } catch (e) {
        debugPrint("Error parsing JSON: $e");
        showCustomSnackBar(
          context,
          Colors.red,
          "Invalid route data received.",
          Colors.white,
          "",
          () {},
        );
        return;
      }

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        debugPrint("No routes found in response");
        showCustomSnackBar(
          context,
          Colors.red,
          "No route found.",
          Colors.white,
          "",
          () {},
        );
        return;
      }

      final route = routes[0] as Map<String, dynamic>?;
      if (route == null || route['geometry'] == null) {
        debugPrint("Invalid route or missing geometry");
        showCustomSnackBar(
          context,
          Colors.red,
          "Invalid route data.",
          Colors.white,
          "",
          () {},
        );
        return;
      }

      final geometry = route['geometry'] as String?;
      if (geometry == null || geometry.isEmpty) {
        debugPrint("Empty or null geometry");
        showCustomSnackBar(
          context,
          Colors.red,
          "No valid route path found.",
          Colors.white,
          "",
          () {},
        );
        return;
      }

      final duration = route['duration'] as num?;
      final distance = route['distance'] as num?;
      List<LatLng> coordinates;
      try {
        coordinates = _decodePolyline(geometry);
        debugPrint("Route coordinates count: ${coordinates.length}");
        if (coordinates.isEmpty) {
          throw Exception("Decoded coordinates are empty");
        }
      } catch (e) {
        debugPrint("Error decoding polyline: $e");
        showCustomSnackBar(
          context,
          Colors.red,
          "Failed to process route path.",
          Colors.white,
          "",
          () {},
        );
        return;
      }

      for (var coord in coordinates) {
        if (coord.latitude.isNaN ||
            coord.longitude.isNaN ||
            coord.latitude.isInfinite ||
            coord.longitude.isInfinite) {
          debugPrint("Invalid coordinate detected: $coord");
          showCustomSnackBar(
            context,
            Colors.red,
            "Invalid route coordinates.",
            Colors.white,
            "",
            () {},
          );
          return;
        }
      }

      if (_routeLine != null) {
        try {
          await _mapController!.removeLine(_routeLine!);
          debugPrint("Previous route removed: ${_routeLine!.id}");
        } catch (e) {
          debugPrint("Error removing previous route: $e");
        }
      }

      try {
        final lineOptions = LineOptions(
          geometry: coordinates,
          lineColor: "#3bb2d0",
          lineWidth: 4.0,
        );
        _routeLine = await _mapController!.addLine(lineOptions);
        debugPrint("Polyline added: ${_routeLine!.id}");
      } catch (e) {
        debugPrint("Error adding polyline: $e");
        showCustomSnackBar(
          context,
          Colors.red,
          "Failed to render route. Falling back to Google Maps.",
          Colors.white,
          "",
          () {},
        );
        try {
          final String googleMapsUrl = 'https://www.google.com/maps/dir/?api=1'
              '&origin=${_userLocation!.latitude},${_userLocation!.longitude}'
              '&destination=${_viewLocation!.latitude},${_viewLocation!.longitude}'
              '&travelmode=driving';
          await launchUrl(
            Uri.parse(googleMapsUrl),
            mode: LaunchMode.externalApplication,
          );
          debugPrint("Launched Google Maps after Mappls failure");
        } catch (e) {
          debugPrint("Error launching Google Maps fallback: $e");
        }
        return;
      }

      try {
        final LatLngBounds bounds = boundsFromLatLngList(coordinates);
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(
            bounds,
            left: 50,
            right: 50,
            top: 100,
            bottom: 100,
          ),
          duration: const Duration(milliseconds: 500),
        );
        debugPrint("Camera adjusted to route bounds");
      } catch (e) {
        debugPrint("Error adjusting camera: $e");
        showCustomSnackBar(
          context,
          Colors.red,
          "Failed to adjust map view.",
          Colors.white,
          "",
          () {},
        );
        return;
      }

      // Show the navigation panel after route is successfully fetched
      if (_scaffoldContext != null && mounted) {
        setState(() {
          _routeDuration = duration?.toDouble();
          _routeDistance = distance?.toDouble();
          _routeCoordinates = coordinates;
          _showNavigationPanel = true;
        });
        debugPrint("Navigation panel displayed");
      } else {
        debugPrint("Scaffold context is null or widget not mounted");
        showCustomSnackBar(
          context,
          Colors.red,
          "Unable to show navigation details.",
          Colors.white,
          "",
          () {},
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
          "Error fetching or rendering route: $e\nStackTrace: $stackTrace");
      showCustomSnackBar(
        context,
        Colors.red,
        "An error occurred while fetching the route. Falling back to Google Maps.",
        Colors.white,
        "",
        () {},
      );
      try {
        final String googleMapsUrl = 'https://www.google.com/maps/dir/?api=1'
            '&origin=${_userLocation!.latitude},${_userLocation!.longitude}'
            '&destination=${_viewLocation!.latitude},${_viewLocation!.longitude}'
            '&travelmode=driving';
        await launchUrl(
          Uri.parse(googleMapsUrl),
          mode: LaunchMode.externalApplication,
        );
        debugPrint("Launched Google Maps after Mappls failure");
      } catch (e) {
        debugPrint("Error launching Google Maps fallback: $e");
      }
    }
  }

  LatLngBounds boundsFromLatLngList(List<LatLng> list) {
    if (list.isEmpty) {
      debugPrint("Empty coordinate list for bounds calculation");
      return LatLngBounds(
        northeast: _viewLocation ?? LatLng(23.188151, 72.636467),
        southwest: _viewLocation ?? LatLng(23.188151, 72.636467),
      );
    }
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      if (x0 == null || x1 == null || y0 == null || y1 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1) y1 = latLng.longitude;
        if (latLng.longitude < y0) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(
        northeast: LatLng(x1!, y1!), southwest: LatLng(x0!, y0!));
  }

  List<LatLng> _decodePolyline(String encoded) {
    if (encoded.isEmpty) {
      debugPrint("Empty polyline string");
      return [];
    }
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    try {
      while (index < len) {
        int b, shift = 0, result = 0;
        do {
          if (index >= len) {
            throw Exception("Invalid polyline: Unexpected end of string");
          }
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lat += dlat;

        shift = 0;
        result = 0;
        do {
          if (index >= len) {
            throw Exception("Invalid polyline: Unexpected end of string");
          }
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lng += dlng;

        points.add(LatLng(lat / 1E5, lng / 1E5));
      }
    } catch (e) {
      debugPrint("Polyline decoding failed: $e");
      return [];
    }
    return points;
  }

  String _formatDuration(double? duration) {
    if (duration == null) return "N/A";
    final minutes = (duration / 60).round();
    if (minutes < 60) {
      return "$minutes min";
    } else {
      final hours = (minutes / 60).floor();
      final remainingMinutes = minutes % 60;
      return "${hours}h ${remainingMinutes}m";
    }
  }

  String _formatDistance(double? distance) {
    if (distance == null) return "N/A";
    final kilometers = distance / 1000;
    return "${kilometers.toStringAsFixed(1)} km";
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final deltaLng = end.longitude - start.longitude;
    final y = sin(deltaLng * pi / 180) * cos(end.latitude * pi / 180);
    final x = cos(start.latitude * pi / 180) * sin(end.latitude * pi / 180) -
        sin(start.latitude * pi / 180) *
            cos(end.latitude * pi / 180) *
            cos(deltaLng * pi / 180);
    final bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  void _showViewBottomSheet() {
    if (_scaffoldContext == null || !mounted) {
      debugPrint("Scaffold context is null or widget not mounted");
      return;
    }
    showModalBottomSheet(
      context: _scaffoldContext!,
      backgroundColor: AppColors.appsecondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    overflow: TextOverflow.ellipsis,
                    widget.view.viewName ?? 'Untitled',
                    textAlign: TextAlign.justify,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        const Shadow(
                          color: Colors.black45,
                          offset: Offset(1, 1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey.withOpacity(0.3),
                      child: IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 16),
                          onPressed: () => Navigator.of(sheetContext).pop()),
                    ),
                  )
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.view.cityName ?? 'Unknown City',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  _buildStarRating(widget.view.averageRating),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        setState(() {
                          _useMapplsNavigation = false;
                        });
                        await _fetchAndDisplayRoute(sheetContext);
                      },
                      icon: const Icon(Icons.directions, color: Colors.white),
                      label: const Text(
                        "Google Maps",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textColorPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        setState(() {
                          _useMapplsNavigation = true;
                        });
                        await _fetchAndDisplayRoute(sheetContext);
                      },
                      icon: const Icon(Icons.directions, color: Colors.white),
                      label: const Text(
                        "Mappls",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textColorPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showDirectionsBottomSheet() {
    if (_scaffoldContext == null || !mounted) {
      debugPrint("Scaffold context is null or widget not mounted");
      return;
    }
    setState(() {
      _showNavigationPanel = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.appprimaryColor,
        title:
            const Text("View Location", style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Builder(
        builder: (BuildContext scaffoldContext) {
          _scaffoldContext = scaffoldContext;
          return Stack(
            children: [
              FutureBuilder(
                  future: _initialTargetFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      debugPrint("FutureBuilder error: ${snapshot.error}");
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (snapshot.hasData) {
                      if (_viewLocation == null) {
                        debugPrint("View location is null, cannot render map");
                        return const Center(
                            child: Text('View location not available'));
                      }
                      return MapplsMap(
                        compassViewMargins: const Point(16, 72),
                        logoViewMargins: const Point(16, 21),
                        logoViewPosition: LogoViewPosition.topLeft,
                        initialCameraPosition: CameraPosition(
                          target: _viewLocation!,
                          zoom: 14.0,
                        ),
                        onMapCreated: (controller) {
                          _mapController = controller;
                          debugPrint("Map controller created");
                          controller.onSymbolTapped.add((symbol) {
                            if (symbol == _viewSymbol) {
                              _showViewBottomSheet();
                            }
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_userLocation == null) {
                              debugPrint(
                                  "User location is null, initializing location");
                              _initializeLocation();
                            }
                          });
                        },
                        onStyleLoadedCallback: () {
                          debugPrint("Map style loaded");
                          _addViewLocationSymbolWithThumbnail();
                        },
                        onMapError: (code, message) {
                          debugPrint("Map error: code=$code, message=$message");
                          showCustomSnackBar(
                            context,
                            Colors.red,
                            "Map failed to load: $message",
                            Colors.white,
                            "",
                            () {},
                          );
                        },
                        myLocationEnabled: _isLocationEnabled,
                        myLocationTrackingMode:
                            MyLocationTrackingMode.trackingCompass,
                        zoomGesturesEnabled: true,
                        scrollGesturesEnabled: true,
                        rotateGesturesEnabled: true,
                        tiltGesturesEnabled: true,
                      );
                    } else {
                      debugPrint("FutureBuilder returned no data");
                      return const Center(
                          child: Text('No location data available'));
                    }
                  }),
              Positioned(
                  bottom: 100,
                  right: 20,
                  child: FloatingActionButton(
                    shape: const CircleBorder(),
                    backgroundColor: AppColors.appsecondaryColor,
                    onPressed: () => _fetchCurrentLocation(),
                    child: _isLocationEnabled
                        ? const Icon(Icons.my_location_rounded,
                            color: Colors.blue)
                        : const ImageIcon(
                            AssetImage("assets/img_location_question.png"),
                            color: Colors.red,
                          ),
                  )),
              if (_showNavigationPanel)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.appsecondaryColor,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                overflow: TextOverflow.ellipsis,
                                "Navigation to ${widget.view.viewName ?? 'Destination'}",
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.grey.withOpacity(0.3),
                                child: IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.white, size: 16),
                                  onPressed: () {
                                    setState(() {
                                      _isNavigationActive = false;
                                      _showNavigationPanel = false;
                                      if (_routeLine != null) {
                                        _mapController?.removeLine(_routeLine!);
                                        _routeLine = null;
                                      }
                                      _routeDuration = null;
                                      _routeDistance = null;
                                      _routeCoordinates = [];
                                    });
                                    _locationUpdateTimer?.cancel();
                                    _mapController?.animateCamera(
                                      CameraUpdate.newCameraPosition(
                                        CameraPosition(
                                          target: _viewLocation!,
                                          zoom: 14.0,
                                          tilt: 0.0,
                                          bearing: 0.0,
                                        ),
                                      ),
                                      duration:
                                          const Duration(milliseconds: 500),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.timer,
                                          color: Colors.white70, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Time: ${_formatDuration(_routeDuration)}",
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.directions,
                                          color: Colors.white70, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Distance: ${_formatDistance(_routeDistance)}",
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: _isNavigationActive
                                ? const SizedBox()
                                : ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _isNavigationActive = true;
                                      });
                                      double bearing = 0.0;
                                      if (_routeCoordinates.length >= 2) {
                                        final start = _routeCoordinates[0];
                                        final next = _routeCoordinates[1];
                                        bearing =
                                            _calculateBearing(start, next);
                                      }
                                      final bounds = boundsFromLatLngList(
                                          _routeCoordinates);
                                      final center = LatLng(
                                        (bounds.northeast.latitude +
                                                bounds.southwest.latitude) /
                                            2,
                                        (bounds.northeast.longitude +
                                                bounds.southwest.longitude) /
                                            2,
                                      );
                                      _mapController!.animateCamera(
                                        CameraUpdate.newCameraPosition(
                                          CameraPosition(
                                            target: center,
                                            zoom: 14.0,
                                            tilt: 45.0,
                                            bearing: bearing,
                                          ),
                                        ),
                                        duration:
                                            const Duration(milliseconds: 500),
                                      );
                                      debugPrint(
                                          "Navigation started with pitch: 45, bearing: $bearing");
                                      _locationUpdateTimer?.cancel();
                                      _locationUpdateTimer = Timer.periodic(
                                          const Duration(seconds: 5), (timer) {
                                        if (_isNavigationActive && mounted) {
                                          debugPrint(
                                              "Periodic location update triggered");
                                          _fetchCurrentLocation(
                                              isNavigationUpdate: true);
                                        }
                                      });
                                      showCustomSnackBar(
                                        context,
                                        AppColors.textColorPrimary,
                                        "Navigation started!",
                                        Colors.white,
                                        "",
                                        () {},
                                      );
                                    },
                                    icon: const Icon(Icons.play_arrow,
                                        color: Colors.white, size: 24),
                                    label: Text(
                                      "Start Navigation",
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          AppColors.textColorPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 12),
                                      elevation: 2,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStarRating(double? rating) {
    final ratingValue = rating?.clamp(0.0, 5.0) ?? 0.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          ratingValue.toStringAsFixed(1),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        const Icon(
          Icons.star,
          color: Colors.amber,
          size: 14,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    if (_mapController != null) {
      if (_userSymbol != null) {
        _mapController!.removeSymbol(_userSymbol!);
      }
      if (_viewSymbol != null) {
        _mapController!.removeSymbol(_viewSymbol!);
      }
      if (_routeLine != null) {
        _mapController!.removeLine(_routeLine!);
      }
    }
    _mapController?.dispose();
    super.dispose();
  }
}
