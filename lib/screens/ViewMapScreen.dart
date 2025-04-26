import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:mappls_gl/mappls_gl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
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
  final TextEditingController _searchController = TextEditingController();
  bool _isLocationEnabled = false;
  Symbol? _userSymbol;
  Symbol? _viewSymbol;
  Symbol? _selectedSymbol;
  Position? _lastKnown;
  late Future<LatLng> _initialTargetFuture;

  @override
  void initState() {
    super.initState();
    _initialTargetFuture = Session().getUserLastLocation();
    debugPrint("Initial Thumbnail URL: ${widget.view.thumbnailImageUrl}");
    if (widget.view.latitude != null && widget.view.longitude != null) {
      _viewLocation = LatLng(widget.view.latitude!, widget.view.longitude!);
    } else {
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

  Future<void> _addViewLocationSymbolWithThumbnail() async {
    if (_mapController == null || _viewLocation == null) {
      debugPrint("Map controller or view location is null");
      return;
    }
    if (_viewSymbol == null && widget.view.thumbnailImageUrl != null) {
      try {
        // Fetch the thumbnail image
        final response =
            await http.get(Uri.parse(widget.view.thumbnailImageUrl!));
        if (response.statusCode == 200) {
          // Decode the image
          img.Image? originalImage = img.decodeImage(response.bodyBytes);
          if (originalImage != null) {
            // Check source image resolution
            if (originalImage.width < 150 || originalImage.height < 150) {
              debugPrint(
                  "Warning: Source image resolution (${originalImage.width}x${originalImage.height}) is low, may affect thumbnail quality");
            }

            // Resize to 150x150 pixels with high-quality interpolation
            img.Image resizedImage = img.copyResize(
              originalImage,
              width: 150,
              height: 150,
              interpolation: img.Interpolation.cubic, // Smoother resizing
            );

            // Create a 180x180 image with a transparent background
            img.Image markerImage =
                img.Image(width: 180, height: 180, numChannels: 4);
            img.fill(markerImage, color: img.ColorRgba8(0, 0, 0, 0));

            // Define center and radii for the circular border
            const int centerX = 90;
            const int centerY = 90;
            const int outerRadius = 90; // Outer edge of the border
            const int innerRadius = 75; // Inner edge of the thumbnail

            // Draw the white border
            img.drawCircle(
              markerImage,
              x: centerX,
              y: centerY,
              radius: outerRadius,
              color: img.ColorRgba8(255, 255, 255, 255), // White border
            );
            img.drawCircle(
              markerImage,
              x: centerX,
              y: centerY,
              radius: innerRadius,
              color: img.ColorRgba8(0, 0, 0, 0), // Transparent inner part
            );

            // Copy the resized image with a circular mask and enhanced anti-aliasing
            for (int y = 0; y < resizedImage.height; y++) {
              for (int x = 0; x < resizedImage.width; x++) {
                double distance = sqrt(pow(x - resizedImage.width / 2, 2) +
                    pow(y - resizedImage.height / 2, 2));
                if (distance <= innerRadius) {
                  markerImage.setPixel(
                      x + 15, y + 15, resizedImage.getPixel(x, y));
                } else if (distance <= innerRadius + 2) {
                  // Enhanced anti-aliasing: Blend pixels within 2-pixel band
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

            // Encode to PNG with minimal compression
            Uint8List customImageBytes =
                Uint8List.fromList(img.encodePng(markerImage, level: 1));

            // Add the custom image to the map
            await _mapController!
                .addImage("custom_thumbnail", customImageBytes);
            // Add the marker with the custom thumbnail
            _viewSymbol = await _mapController!.addSymbol(
              SymbolOptions(
                geometry: _viewLocation!,
                iconImage: "custom_thumbnail",
                iconSize: 0.8, // Reduced to make marker smaller
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
        // Center the map on the view location
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_viewLocation!, 14.0),
          duration: const Duration(milliseconds: 500),
        );
      } catch (e) {
        debugPrint("Error loading custom thumbnail: $e");
        _viewSymbol = await _mapController!.addSymbol(
          SymbolOptions(
            geometry: _viewLocation!,
            iconImage: "assets/add_location.png",
            iconSize: 1.0,
          ),
        );
      }
    } else if (_viewSymbol != null) {
      _mapController!.updateSymbol(
        _viewSymbol!,
        SymbolOptions(geometry: _viewLocation!),
      );
    }
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
      body: Stack(
        children: [
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
                      target: _viewLocation ?? snapshot.data!,
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
                    onStyleLoadedCallback: () =>
                        {_addViewLocationSymbolWithThumbnail()},
                    myLocationEnabled: _isLocationEnabled,
                    myLocationTrackingMode:
                        MyLocationTrackingMode.trackingCompass,
                  );
                } else {
                  return const Center(child: Text(''));
                }
              }),
          Positioned(
              bottom: 100,
              right: 20,
              child: FloatingActionButton(
                shape: const CircleBorder(),
                backgroundColor: AppColors.appsecondaryColor,
                onPressed: _fetchCurrentLocation,
                child: _isLocationEnabled
                    ? const Icon(Icons.my_location_rounded, color: Colors.blue)
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
