import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:custom_radio_grouped_button/custom_radio_grouped_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:panorama_viewer/panorama_viewer.dart';
import 'package:tuple/tuple.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/MarkerData.dart';
import '../data/PanoramaImage.dart';
import '../data/ViewData.dart';
import '../utils/RippleWaveIcon.dart';
import '../utils/appColors.dart';
import 'ExploreScreen.dart';

class PanoramaView extends StatefulWidget {
  final ViewData view;
  const PanoramaView({super.key, required this.view});

  @override
  State<PanoramaView> createState() => _PanoramaViewState();
}

class _PanoramaViewState extends State<PanoramaView>
    with SingleTickerProviderStateMixin {
  final Map<String, ImageProvider> _imageCache = {};

  bool _isFirstLoad = false;
  int? _selectedIndex;
  late MarkerData selectedMarker;
  int currentImageId = 0;
  late List<PanoramaImage> panoramaImages = [];
  bool _isPreviewListOpen = false;
  bool _isSettingsOpen = false;
  late bool _isAnimationEnable = false;
  late bool _showHotspots = true;
  late bool _isBgMusicEnable = false;
  List<String> interactionMode = ["Touch"];
  String viewModes = "Phone";
  String iconSize = "M";
  double iconOpacity = 1;
  double _animationSpeed = 1;

  int? _tappedMarkerIndex;
  bool _isSheetVisible = false;
  bool _isAddressExpanded = false;
  bool _isAboutExpanded = false;
  double _sheetHeightFactor = 0.0;
  final double _minSheetHeightFactor = 0.18;
  final double _halfSheetHeightFactor = 0.36;
  final double _maxSheetHeightFactor = 0.95;
  late TabController _tabController;

  // VR-specific state
  MarkerData? _hoveredMarker;
  bool _isCloseButtonHovered = false;
  Timer? _gazeTimer;
  bool _isGazeActive = false;
  double _gazeProgress = 0.0; // Progress of gaze interaction (0 to 1)
  final Duration _gazeDuration =
      const Duration(seconds: 2); // Time to trigger hotspot

  void initializeView() {
    panoramaImages = widget.view.panoramaImages;
  }

  @override
  void initState() {
    super.initState();
    initializeView();
    _tabController = TabController(length: 4, vsync: this);
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  }

  void preloadAdjacentImages(BuildContext context) {
    if (currentImageId > 0) {
      precacheImage(
        CachedNetworkImageProvider(
          panoramaImages[currentImageId - 1].imageUrl!,
          cacheManager: customCacheManager,
        ),
        context,
      );
    }
    if (currentImageId < panoramaImages.length - 1) {
      precacheImage(
        CachedNetworkImageProvider(
          panoramaImages[currentImageId + 1].imageUrl!,
          cacheManager: customCacheManager,
        ),
        context,
      );
    }
  }

  void precacheCurrentImage(BuildContext context) {
    final currentImage = panoramaImages[currentImageId];
    if (currentImage.image != null && currentImage.image!.existsSync()) {
      precacheImage(FileImage(currentImage.image!), context);
    } else if (currentImage.imageUrl != null) {
      precacheImage(
        NetworkImage(currentImage.imageUrl!),
        context,
        onError: (exception, stackTrace) {},
      );
    }
  }

  ImageProvider getCachedImage(File file) {
    final path = file.path;
    if (_imageCache.containsKey(path)) {
      return _imageCache[path]!;
    }
    final provider = FileImage(file);
    _imageCache[path] = provider;
    return provider;
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _tabController.dispose();
    _gazeTimer?.cancel();
    super.dispose();
  }

  void _showMarkerLabel() {
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _tappedMarkerIndex = null;
      });
    });
  }

  void _openSheet() {
    setState(() {
      _isSheetVisible = true;
      _sheetHeightFactor = _minSheetHeightFactor;
    });
  }

  Future<void> _toggleSheet() async {
    setState(() {
      if (_sheetHeightFactor == 0) {
        _openSheet();
      } else if (_sheetHeightFactor == _minSheetHeightFactor) {
        _sheetHeightFactor = _halfSheetHeightFactor;
      } else if (_sheetHeightFactor == _halfSheetHeightFactor) {
        _sheetHeightFactor = _maxSheetHeightFactor;
      } else {
        _sheetHeightFactor = _minSheetHeightFactor;
      }
    });
  }

  void _closeSheetFully() {
    setState(() {
      _isSheetVisible = false;
      _sheetHeightFactor = 0.0;
    });
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url.startsWith("http") ? url : "https://$url");
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  Future<void> _launchPhone(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: "tel", path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      throw 'Could not launch $phoneUri';
    }
  }

  void _startGazeTimer(MarkerData? marker, {bool isCloseButton = false}) {
    setState(() {
      _hoveredMarker = marker;
      _isCloseButtonHovered = isCloseButton;
      _isGazeActive = true;
      _gazeProgress = 0.0;
    });

    _gazeTimer?.cancel();
    _gazeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _gazeProgress += 50 / _gazeDuration.inMilliseconds;
        if (_gazeProgress >= 1.0) {
          _gazeTimer?.cancel();
          _isGazeActive = false;
          _gazeProgress = 0.0;
          if (isCloseButton) {
            _exitVRMode();
          } else if (marker != null) {
            _triggerHotspot(marker);
          }
        }
      });
    });
  }

  void _cancelGazeTimer() {
    _gazeTimer?.cancel();
    setState(() {
      _hoveredMarker = null;
      _isCloseButtonHovered = false;
      _isGazeActive = false;
      _gazeProgress = 0.0;
    });
  }

  void _triggerHotspot(MarkerData marker) {
    setState(() {
      if (marker.selectedAction == "Label") {
        selectedMarker = marker;
        _tappedMarkerIndex = marker.hashCode;
        _closeSheetFully();
        _showMarkerLabel();
      } else if (marker.selectedAction == "Navigation") {
        _selectedIndex = currentImageId = marker.nextImageId;
      } else if (marker.selectedAction == "Banner") {
        _tappedMarkerIndex = null;
        selectedMarker = marker;
        _openSheet();
      }
    });
  }

  void _exitVRMode() {
    setState(() {
      viewModes = "Phone";
      interactionMode = ["Touch"];
    });
  }

  bool _isCursorOverHotspot(double cursorLong, double cursorLat,
      double markerLong, double markerLat) {
    // Convert to radians
    final double markerLongRad = markerLong * math.pi / 180;
    final double markerLatRad = markerLat * math.pi / 180;
    final double cursorLongRad = cursorLong * math.pi / 180;
    final double cursorLatRad = cursorLat * math.pi / 180;

    // Haversine formula to calculate angular distance
    final double dLat = cursorLatRad - markerLatRad;
    final double dLong = cursorLongRad - markerLongRad;
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(markerLatRad) *
            math.cos(cursorLatRad) *
            math.sin(dLong / 2) *
            math.sin(dLong / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final double distance = c * 180 / math.pi; // Convert back to degrees

    // Consider hotspot hovered if within 5 degrees
    return distance < 5.0;
  }

  Widget _buildPanoramaViewer({bool isLeftEye = false}) {
    final currentImage =
        panoramaImages.isNotEmpty ? panoramaImages[currentImageId] : null;

    // Define close button hotspot coordinates (top-right quadrant)
    const double closeButtonLongitude = 45.0; // Right side
    const double closeButtonLatitude = -45.0; // Upper side

    return Stack(
      alignment: Alignment.center,
      children: [
        PanoramaViewer(
          key: ValueKey(Tuple4(_animationSpeed, _isAnimationEnable,
              interactionMode.toString(), currentImageId)),
          animSpeed: _isAnimationEnable ? _animationSpeed : 0,
          animReverse: true,
          sensitivity: 1.8,
          interactive:
              viewModes == "VR" ? false : interactionMode.contains("Touch"),
          sensorControl: viewModes == "VR"
              ? SensorControl.absoluteOrientation
              : interactionMode.contains("Gyro")
                  ? SensorControl.absoluteOrientation
                  : SensorControl.none,
          hotspots: _showHotspots
              ? [
                  // Regular hotspots
                  ...(currentImage?.markers.map((marker) {
                        return Hotspot(
                          height: 60,
                          width: 240,
                          longitude: marker.longitude,
                          latitude: marker.latitude,
                          name: marker.label,
                          widget: (_tappedMarkerIndex == marker.hashCode)
                              ? Container(
                                  padding: const EdgeInsets.all(4.0),
                                  decoration: const BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(4))),
                                  child: Center(
                                    child: Text(
                                      selectedMarker.label,
                                      textAlign: TextAlign.start,
                                      style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                )
                              : Opacity(
                                  opacity: iconOpacity,
                                  child: Transform(
                                    transform: (marker.selectedIconStyle ==
                                            "Flat")
                                        ? (Matrix4.identity()
                                          ..rotateX(math.pi / 8)
                                          ..rotateZ(marker
                                              .selectedIconRotationRadians))
                                        : (Matrix4.identity()
                                          ..rotateZ(marker
                                              .selectedIconRotationRadians)),
                                    alignment: Alignment.center,
                                    child: RippleWaveIcon(
                                      icon: marker.selectedIcon,
                                      rippleColor: marker.selectedIconColor,
                                      iconSize: (iconSize == "S")
                                          ? 18
                                          : (iconSize == "M")
                                              ? 24
                                              : 32,
                                      iconColor: marker.selectedIconColor,
                                      rippleDuration:
                                          const Duration(seconds: 3),
                                      onTap: viewModes == "VR"
                                          ? () {} // Empty callback for VR mode
                                          : () {
                                              setState(() {
                                                if (marker.selectedAction ==
                                                    "Label") {
                                                  selectedMarker = marker;
                                                  _tappedMarkerIndex =
                                                      marker.hashCode;
                                                  _closeSheetFully();
                                                }
                                              });

                                              if (marker.selectedAction ==
                                                  "Label") {
                                                _showMarkerLabel();
                                              } else if (marker
                                                      .selectedAction ==
                                                  "Navigation") {
                                                setState(() {
                                                  _selectedIndex =
                                                      currentImageId =
                                                          marker.nextImageId;
                                                });
                                              } else if (marker
                                                      .selectedAction ==
                                                  "Banner") {
                                                setState(() {
                                                  _tappedMarkerIndex = null;
                                                  selectedMarker = marker;
                                                });
                                                _openSheet();
                                              }
                                            },
                                    ),
                                  ),
                                ),
                        );
                      }).toList() ??
                      []),
                  // Close button hotspot (VR mode only)
                  if (viewModes == "VR")
                    Hotspot(
                      height: 40,
                      width: 40,
                      longitude: closeButtonLongitude,
                      latitude: closeButtonLatitude,
                      name: "Close",
                      widget: GestureDetector(
                        onTap: _exitVRMode,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isCloseButtonHovered
                                ? Colors.red.withOpacity(0.9)
                                : Colors.grey.withOpacity(0.7),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 5,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                ]
              : [],
          onImageLoad: () {
            if (!_isFirstLoad) {
              _isFirstLoad = true;
              setState(() {
                _selectedIndex = 0;
              });
            }
          },
          onTap: (longitude, latitude, tilt) => {
            setState(() {
              _isSettingsOpen = false;
              if (viewModes == "VR") {
                // Exit VR mode on double-tap
                Future.delayed(const Duration(milliseconds: 300), () {
                  setState(() {
                    viewModes = "Phone";
                    interactionMode = ["Touch"];
                  });
                });
              }
            })
          },
          onViewChanged: viewModes == "VR"
              ? (longitude, latitude, tilt) {
                  // Check for hotspot hover
                  MarkerData? newHoveredMarker;
                  if (_showHotspots) {
                    for (var marker in currentImage!.markers) {
                      if (_isCursorOverHotspot(longitude, latitude,
                          marker.longitude, marker.latitude)) {
                        newHoveredMarker = marker;
                        break;
                      }
                    }
                  }
                  // Check for close button hover
                  bool isCloseButtonHovered = viewModes == "VR" &&
                      _isCursorOverHotspot(longitude, latitude,
                          closeButtonLongitude, closeButtonLatitude);

                  if (newHoveredMarker != _hoveredMarker ||
                      isCloseButtonHovered != _isCloseButtonHovered) {
                    _cancelGazeTimer();
                    if (isCloseButtonHovered) {
                      _startGazeTimer(null, isCloseButton: true);
                    } else if (newHoveredMarker != null) {
                      _startGazeTimer(newHoveredMarker);
                    }
                  }
                }
              : null,
          child:
              currentImage?.image != null && currentImage!.image!.existsSync()
                  ? Image(
                      image: getCachedImage(currentImage.image!),
                      errorBuilder: (BuildContext context, Object error,
                          StackTrace? stackTrace) {
                        return Image.asset('assets/image_load_failed.png');
                      },
                    )
                  : currentImage?.imageUrl != null
                      ? Image(
                          image: CachedNetworkImageProvider(
                            currentImage!.imageUrl!,
                            cacheManager: customCacheManager,
                          ),
                          errorBuilder: (BuildContext context, Object error,
                              StackTrace? stackTrace) {
                            return Image.asset('assets/image_load_failed.png');
                          },
                        )
                      : Image.asset('assets/image_load_failed.png'),
        ),
        // Cursor for VR mode
        if (viewModes == "VR")
          Stack(
            alignment: Alignment.center,
            children: [
              // Cursor dot
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 3,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              // Gaze progress animation
              if (_isGazeActive)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 50),
                  width: 10 * _gazeProgress,
                  height: 10 * _gazeProgress,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.7),
                      width: 2,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    final currentImage =
        panoramaImages.isNotEmpty ? panoramaImages[currentImageId] : null;

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final sheetWidth = isLandscape
        ? MediaQuery.of(context).size.width / 2
        : MediaQuery.of(context).size.width;
    final sheetLeft = isLandscape ? 0 : 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.appprimaryBackgroundColor,
      body: Stack(
        children: [
          // VR Mode: Side-by-Side PanoramaViewer
          if (viewModes == "VR")
            Row(
              children: [
                Expanded(
                  child: ClipRect(
                    child: _buildPanoramaViewer(isLeftEye: true), // Left eye
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: _buildPanoramaViewer(isLeftEye: false), // Right eye
                  ),
                ),
              ],
            )
          else
            // Phone Mode: Single PanoramaViewer
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: _buildPanoramaViewer(),
            ),

          // UI Elements (Hidden in VR Mode)
          if (viewModes != "VR")
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  top: 20,
                  left: 12,
                  child: GestureDetector(
                    onTap: () {
                      if (viewModes == "VR") {
                        setState(() {
                          viewModes = "Phone";
                          interactionMode = ["Touch"];
                        });
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.appsecondaryColor,
                        borderRadius: BorderRadius.circular(45),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 5,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  right: 12,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isSettingsOpen = !_isSettingsOpen;
                      });
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.appsecondaryColor,
                        borderRadius: BorderRadius.circular(45),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 5,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.menu_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  bottom: _isPreviewListOpen ? 0 : -90,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: double.infinity,
                          height: 90,
                          decoration:
                              const BoxDecoration(color: Colors.black45),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 5),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: panoramaImages.length,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    currentImageId = index;
                                    _selectedIndex = index;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: _selectedIndex == index
                                                ? Colors.blue
                                                : Colors.transparent,
                                            width: _selectedIndex == index
                                                ? 2.0
                                                : 0.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(2),
                                          child: SizedBox(
                                            width: 120,
                                            child: panoramaImages[index]
                                                            .image !=
                                                        null &&
                                                    panoramaImages[index]
                                                        .image!
                                                        .existsSync()
                                                ? Image.file(
                                                    panoramaImages[index]
                                                        .image!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (BuildContext context,
                                                            Object error,
                                                            StackTrace?
                                                                stackTrace) {
                                                      return Image.asset(
                                                          'assets/image_load_failed.png');
                                                    },
                                                  )
                                                : CachedNetworkImage(
                                                    cacheManager:
                                                        customCacheManager,
                                                    imageUrl:
                                                        panoramaImages[index]
                                                            .imageUrl!,
                                                    fit: BoxFit.cover,
                                                    placeholder:
                                                        (context, url) =>
                                                            const Center(
                                                      child: SizedBox(
                                                        width: 15,
                                                        height: 15,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                    errorWidget:
                                                        (context, url, error) =>
                                                            Image.asset(
                                                      'assets/image_load_failed.png',
                                                    ),
                                                    memCacheWidth: 200,
                                                  ),
                                          ),
                                        ),
                                      ),
                                      if (panoramaImages[index]
                                          .markers
                                          .isNotEmpty)
                                        Positioned(
                                          top: 5,
                                          right: 5,
                                          child: Row(
                                            children: [
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    panoramaImages
                                                        .removeAt(index);
                                                    _selectedIndex = null;
                                                  });
                                                },
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.red
                                                        .withOpacity(0.7),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.all(4),
                                                  child: const Icon(
                                                    Icons.location_on,
                                                    size: 15,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      Positioned(
                                        bottom: 5,
                                        left: 5,
                                        child: Container(
                                          constraints: const BoxConstraints(
                                              maxWidth: 100),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withAlpha(140),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            panoramaImages[index]
                                                .imageName
                                                .toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  bottom: _isPreviewListOpen ? 83 : 10,
                  child: GestureDetector(
                    onTap: () => {
                      setState(() {
                        _isPreviewListOpen = !_isPreviewListOpen;
                      })
                    },
                    child: Container(
                      width: 65,
                      height: 25,
                      decoration: BoxDecoration(
                        color: AppColors.appsecondaryColor,
                        borderRadius: BorderRadius.circular(45),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 5,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          _isPreviewListOpen
                              ? Icons.arrow_drop_down_rounded
                              : Icons.arrow_drop_up_rounded,
                          color: Colors.white70,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  bottom: _isPreviewListOpen ? 95 : 10,
                  left: 12,
                  child: GestureDetector(
                    onTap: currentImageId > 0
                        ? () {
                            setState(() {
                              currentImageId--;
                              preloadAdjacentImages(context);
                              precacheCurrentImage(context);
                              _selectedIndex = currentImageId;
                            });
                          }
                        : null,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.appsecondaryColor,
                        borderRadius: BorderRadius.circular(45),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 5,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.arrow_left_rounded,
                          color: currentImageId > 0
                              ? Colors.white70
                              : Colors.white12,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  bottom: _isPreviewListOpen ? 95 : 10,
                  right: 12,
                  child: GestureDetector(
                    onTap: currentImageId < panoramaImages.length - 1
                        ? () {
                            setState(() {
                              currentImageId++;
                              preloadAdjacentImages(context);
                              precacheCurrentImage(context);
                              _selectedIndex = currentImageId;
                            });
                          }
                        : null,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.appsecondaryColor,
                        borderRadius: BorderRadius.circular(45),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 5,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.arrow_right_rounded,
                          color: currentImageId < panoramaImages.length - 1
                              ? Colors.white70
                              : Colors.white12,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  right: _isSettingsOpen ? 0 : -270,
                  bottom: 0,
                  top: 0,
                  child: AnimatedContainer(
                    color: AppColors.appprimaryColor,
                    duration: const Duration(milliseconds: 300),
                    width: 270,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isSettingsOpen = !_isSettingsOpen;
                                  });
                                },
                                child: const Center(
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: Colors.teal,
                                    size: 25,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  "Show Animation",
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Switch(
                                padding: const EdgeInsets.all(0),
                                value: _isAnimationEnable,
                                onChanged: (bool value) {
                                  setState(() {
                                    _isAnimationEnable = value;
                                    if (_isAnimationEnable) {
                                      _animationSpeed = 1.0;
                                    } else {
                                      _animationSpeed = 0.0;
                                    }
                                  });
                                },
                                activeColor: Colors.white,
                                activeTrackColor: Colors.white.withOpacity(0.8),
                                inactiveThumbColor: Colors.grey,
                                inactiveTrackColor:
                                    Colors.grey.withOpacity(0.5),
                              ),
                            ],
                          ),
                          if (_isAnimationEnable) ...[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Animation Speed: ",
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.white),
                                ),
                                Text(
                                  "${(_animationSpeed).toInt()}x",
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 2.0,
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 8),
                                    overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 0),
                                  ),
                                  child: Slider(
                                    value: _animationSpeed,
                                    min: 1,
                                    max: 100,
                                    divisions: 100,
                                    label: "${(_animationSpeed).toInt()}",
                                    onChanged: (double newValue) {
                                      setState(() {
                                        _animationSpeed = newValue;
                                      });
                                    },
                                    activeColor: Colors.teal,
                                    inactiveColor: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  "Show Hotspot",
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Switch(
                                padding: const EdgeInsets.all(0),
                                value: _showHotspots,
                                onChanged: (bool value) {
                                  setState(() {
                                    iconOpacity = (value == false) ? 0 : 1;
                                    _showHotspots = value;
                                  });
                                },
                                activeColor: Colors.white,
                                activeTrackColor: Colors.white.withOpacity(0.8),
                                inactiveThumbColor: Colors.grey,
                                inactiveTrackColor:
                                    Colors.grey.withOpacity(0.5),
                              ),
                            ],
                          ),
                          if (_showHotspots) ...[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Icon Opacity: ",
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.white),
                                ),
                                Text(
                                  "${(iconOpacity * 100).toInt()}%",
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 2.0,
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 8),
                                    overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 0),
                                  ),
                                  child: Slider(
                                    value: iconOpacity,
                                    min: 0.1,
                                    max: 1.0,
                                    divisions: 100,
                                    label: "${(iconOpacity * 100).toInt()}%",
                                    onChanged: (double newValue) {
                                      setState(() {
                                        iconOpacity = newValue;
                                      });
                                    },
                                    activeColor: Colors.teal,
                                    inactiveColor: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          const Text(
                            "Icon Size:",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                          Row(
                            children: [
                              CustomRadioButton(
                                width: 50,
                                buttonLables: const ["S", "M", "L"],
                                buttonValues: const ["S", "M", "L"],
                                radioButtonValue: (values) {
                                  setState(() {
                                    iconSize = values;
                                  });
                                },
                                defaultSelected: iconSize,
                                enableShape: true,
                                customShape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                selectedColor: Colors.teal,
                                unSelectedColor: Colors.grey.shade800,
                                selectedBorderColor: Colors.tealAccent,
                                unSelectedBorderColor: Colors.grey.shade600,
                                buttonTextStyle: const ButtonTextStyle(
                                  selectedColor: Colors.white,
                                  unSelectedColor: Colors.white70,
                                  textStyle: TextStyle(fontSize: 14),
                                ),
                                padding: 10,
                                margin: EdgeInsets.only(right: 10, top: 10),
                                elevation: 4,
                                horizontal: false,
                                height: 22,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Interaction Mode:",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                          Row(
                            children: [
                              CustomCheckBoxGroup(
                                autoWidth: true,
                                buttonLables: const ["Gyro", "Touch"],
                                buttonValuesList: const ["Gyro", "Touch"],
                                checkBoxButtonValues: (values) {
                                  setState(() {
                                    interactionMode = List<String>.from(values);
                                  });
                                },
                                defaultSelected: interactionMode,
                                enableShape: true,
                                customShape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                selectedColor: Colors.teal,
                                unSelectedColor: Colors.grey.shade800,
                                selectedBorderColor: Colors.tealAccent,
                                unSelectedBorderColor: Colors.grey.shade600,
                                buttonTextStyle: const ButtonTextStyle(
                                  selectedColor: Colors.white,
                                  unSelectedColor: Colors.white70,
                                  textStyle: TextStyle(fontSize: 14),
                                ),
                                padding: 10,
                                margin: EdgeInsets.only(right: 10, top: 10),
                                elevation: 4,
                                horizontal: false,
                                height: 22,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Play as:",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                          Row(
                            children: [
                              CustomRadioButton(
                                autoWidth: true,
                                buttonLables: const ["VR", "Phone"],
                                buttonValues: const ["VR", "Phone"],
                                radioButtonValue: (values) {
                                  setState(() {
                                    viewModes = values;
                                    if (values == "VR") {
                                      interactionMode = ["Gyro"];
                                      _isSettingsOpen = false;
                                      _isPreviewListOpen = false;
                                      _isSheetVisible = false;
                                    }
                                  });
                                },
                                defaultSelected: viewModes,
                                enableShape: true,
                                customShape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                selectedColor: Colors.teal,
                                unSelectedColor: Colors.grey.shade800,
                                selectedBorderColor: Colors.tealAccent,
                                unSelectedBorderColor: Colors.grey.shade600,
                                buttonTextStyle: const ButtonTextStyle(
                                  selectedColor: Colors.white,
                                  unSelectedColor: Colors.white70,
                                  textStyle: TextStyle(fontSize: 14),
                                ),
                                padding: 10,
                                margin: EdgeInsets.only(right: 10, top: 10),
                                elevation: 4,
                                horizontal: false,
                                height: 22,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

          // Bottom Sheet (Hidden in VR Mode)
          if (_isSheetVisible && viewModes != "VR")
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: sheetLeft.toDouble(),
              bottom: _isSheetVisible
                  ? 0
                  : -MediaQuery.of(context).size.height * _minSheetHeightFactor,
              width: sheetWidth,
              height: MediaQuery.of(context).size.height * _sheetHeightFactor,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  setState(() {
                    double newHeight = _sheetHeightFactor -
                        details.primaryDelta! /
                            MediaQuery.of(context).size.height;
                    _sheetHeightFactor = newHeight.clamp(
                        _minSheetHeightFactor, _maxSheetHeightFactor);
                  });
                },
                onVerticalDragEnd: (details) {
                  double velocity = details.primaryVelocity ?? 0;
                  if (velocity < -500 || _sheetHeightFactor > 0.75) {
                    _sheetHeightFactor = _maxSheetHeightFactor;
                  } else if (_sheetHeightFactor > 0.35) {
                    _sheetHeightFactor = _halfSheetHeightFactor;
                  } else {
                    _sheetHeightFactor = _minSheetHeightFactor;
                  }
                  setState(() {});
                },
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.appsecondaryColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(25),
                        topRight: Radius.circular(25),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _toggleSheet,
                          child: Container(
                            width: 50,
                            height: 4,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedMarker.label,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: _sheetHeightFactor ==
                                              _minSheetHeightFactor
                                          ? 1
                                          : 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      selectedMarker.subTitle,
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: _closeSheetFully,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.grey.withOpacity(0.7),
                                      ),
                                      padding: const EdgeInsets.all(6),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        DefaultTabController(
                          length: 4,
                          child: Expanded(
                            child: Column(
                              children: [
                                TabBar(
                                  controller: _tabController,
                                  labelColor: Colors.white,
                                  unselectedLabelColor: Colors.grey,
                                  indicatorColor: Colors.white,
                                  tabs: const [
                                    Tab(text: "Overview"),
                                    Tab(text: "Features"),
                                    Tab(text: "Photos"),
                                    Tab(text: "About"),
                                  ],
                                ),
                                Expanded(
                                  child: TabBarView(
                                    controller: _tabController,
                                    children: [
                                      SingleChildScrollView(
                                        child: Column(
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 18.0,
                                                      vertical: 12),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  const Icon(
                                                    Icons.location_on_outlined,
                                                    color: Colors.blue,
                                                    size: 24,
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Text(
                                                      selectedMarker.address,
                                                      softWrap: true,
                                                      maxLines:
                                                          _isAddressExpanded
                                                              ? null
                                                              : 2,
                                                      overflow:
                                                          _isAddressExpanded
                                                              ? TextOverflow
                                                                  .visible
                                                              : TextOverflow
                                                                  .ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        _isAddressExpanded =
                                                            !_isAddressExpanded;
                                                      });
                                                    },
                                                    icon: Icon(
                                                      _isAddressExpanded
                                                          ? Icons
                                                              .keyboard_arrow_up_rounded
                                                          : Icons
                                                              .keyboard_arrow_down_rounded,
                                                    ),
                                                    color: Colors.white70,
                                                    iconSize: 24,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Divider(
                                                height: 1, color: Colors.grey),
                                            GestureDetector(
                                              onTap: () => {
                                                if (selectedMarker
                                                        .phoneNumber !=
                                                    null)
                                                  {
                                                    _launchPhone(selectedMarker
                                                        .phoneNumber
                                                        .toString())
                                                  }
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 18.0,
                                                        vertical: 12),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    const Icon(
                                                      Icons.phone,
                                                      color: Colors.blue,
                                                      size: 24,
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Text(
                                                        selectedMarker
                                                                    .phoneNumber ==
                                                                null
                                                            ? "---"
                                                            : selectedMarker
                                                                .phoneNumber
                                                                .toString(),
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const Divider(
                                                height: 1, color: Colors.grey),
                                            GestureDetector(
                                              onTap: () => {
                                                if (selectedMarker.link != null)
                                                  {
                                                    _launchUrl(selectedMarker
                                                        .link
                                                        .toString())
                                                  }
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 18.0,
                                                        vertical: 12),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    const Icon(
                                                      Icons.public_rounded,
                                                      color: Colors.blue,
                                                      size: 24,
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Text(
                                                        selectedMarker
                                                                    .linkLabel ==
                                                                null
                                                            ? "---"
                                                            : selectedMarker
                                                                .linkLabel
                                                                .toString(),
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const Divider(
                                                height: 1, color: Colors.grey),
                                            GestureDetector(
                                              onTap: () =>
                                                  _tabController.animateTo(3),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 18.0,
                                                    vertical: 12),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      "See all",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const Divider(
                                                height: 2, color: Colors.grey),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        children: [
                                          Expanded(
                                            child: ListView(
                                              shrinkWrap: true,
                                              children: const [
                                                ListTile(
                                                  title: Text(
                                                    'Option 1',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                Divider(
                                                    height: 0,
                                                    color: Colors.grey),
                                                ListTile(
                                                  title: Text(
                                                    'Option 2',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                Divider(
                                                    height: 0,
                                                    color: Colors.grey),
                                                ListTile(
                                                  title: Text(
                                                    'Option 3',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                Divider(
                                                    height: 0,
                                                    color: Colors.grey),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: MasonryGridView.count(
                                          crossAxisCount: 2,
                                          mainAxisSpacing: 8,
                                          crossAxisSpacing: 8,
                                          itemCount: selectedMarker
                                                  .bannerImageUrl?.length ??
                                              selectedMarker
                                                  .bannerImage?.length ??
                                              0,
                                          itemBuilder: (context, index) {
                                            return ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: selectedMarker
                                                              .bannerImage !=
                                                          null &&
                                                      index <
                                                          selectedMarker
                                                              .bannerImage!
                                                              .length &&
                                                      selectedMarker
                                                                  .bannerImage![
                                                              index] !=
                                                          null &&
                                                      selectedMarker
                                                          .bannerImage![index]!
                                                          .existsSync()
                                                  ? Image.file(
                                                      selectedMarker
                                                          .bannerImage![index]!,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (BuildContext context,
                                                              Object error,
                                                              StackTrace?
                                                                  stackTrace) {
                                                        return Image.asset(
                                                            'assets/image_load_failed.png');
                                                      },
                                                    )
                                                  : selectedMarker.bannerImageUrl !=
                                                              null &&
                                                          index <
                                                              selectedMarker
                                                                  .bannerImageUrl!
                                                                  .length &&
                                                          selectedMarker
                                                              .bannerImageUrl![
                                                                  index]
                                                              .isNotEmpty
                                                      ? CachedNetworkImage(
                                                          cacheManager:
                                                              customCacheManager,
                                                          imageUrl: selectedMarker
                                                                  .bannerImageUrl![
                                                              index],
                                                          fit: BoxFit.cover,
                                                          placeholder:
                                                              (context, url) =>
                                                                  const Center(
                                                            child:
                                                                CircularProgressIndicator(
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                          errorWidget: (context,
                                                                  url, error) =>
                                                              Image.asset(
                                                            'assets/image_load_failed.png',
                                                          ),
                                                          memCacheWidth: 400,
                                                        )
                                                      : Image.asset(
                                                          'assets/image_load_failed.png'),
                                            );
                                          },
                                        ),
                                      ),
                                      SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 18.0,
                                                  left: 18,
                                                  top: 12),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        const Text(
                                                          "About",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 6),
                                                        Text(
                                                          "\"${selectedMarker.description}\"",
                                                          softWrap: true,
                                                          maxLines:
                                                              _isAboutExpanded
                                                                  ? null
                                                                  : 2,
                                                          overflow:
                                                              _isAboutExpanded
                                                                  ? TextOverflow
                                                                      .visible
                                                                  : TextOverflow
                                                                      .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                            color:
                                                                Colors.white70,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                IconButton(
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                  onPressed: () {
                                                    setState(() {
                                                      _isAboutExpanded =
                                                          !_isAboutExpanded;
                                                    });
                                                  },
                                                  icon: Icon(
                                                    _isAboutExpanded
                                                        ? Icons
                                                            .keyboard_arrow_up_rounded
                                                        : Icons
                                                            .keyboard_arrow_down_rounded,
                                                  ),
                                                  color: Colors.white70,
                                                  iconSize: 20,
                                                ),
                                                GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _isAboutExpanded =
                                                          !_isAboutExpanded;
                                                    });
                                                  },
                                                  child: Text(
                                                    _isAboutExpanded
                                                        ? "Less"
                                                        : "More",
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Divider(
                                                height: 0,
                                                thickness: 1,
                                                color: Colors.grey),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 18.0,
                                                      vertical: 12),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  const Icon(
                                                    Icons.location_on_outlined,
                                                    color: Colors.blue,
                                                    size: 24,
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Text(
                                                      selectedMarker.address,
                                                      softWrap: true,
                                                      maxLines:
                                                          _isAddressExpanded
                                                              ? null
                                                              : 2,
                                                      overflow:
                                                          _isAddressExpanded
                                                              ? TextOverflow
                                                                  .visible
                                                              : TextOverflow
                                                                  .ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        _isAddressExpanded =
                                                            !_isAddressExpanded;
                                                      });
                                                    },
                                                    icon: Icon(
                                                      _isAddressExpanded
                                                          ? Icons
                                                              .keyboard_arrow_up_rounded
                                                          : Icons
                                                              .keyboard_arrow_down_rounded,
                                                    ),
                                                    color: Colors.white70,
                                                    iconSize: 24,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Divider(
                                                height: 1, color: Colors.grey),
                                            GestureDetector(
                                              onTap: () => {
                                                if (selectedMarker
                                                        .phoneNumber !=
                                                    null)
                                                  {
                                                    _launchPhone(selectedMarker
                                                        .phoneNumber
                                                        .toString())
                                                  }
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 18.0,
                                                        vertical: 12),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    const Icon(
                                                      Icons.phone,
                                                      color: Colors.blue,
                                                      size: 24,
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Text(
                                                        selectedMarker
                                                                    .phoneNumber ==
                                                                null
                                                            ? "---"
                                                            : selectedMarker
                                                                .phoneNumber
                                                                .toString(),
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const Divider(
                                                height: 1, color: Colors.grey),
                                            GestureDetector(
                                              onTap: () => {
                                                if (selectedMarker.link != null)
                                                  {
                                                    _launchUrl(selectedMarker
                                                        .link
                                                        .toString())
                                                  }
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 18.0,
                                                        vertical: 12),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    const Icon(
                                                      Icons.public_rounded,
                                                      color: Colors.blue,
                                                      size: 24,
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Text(
                                                        selectedMarker
                                                                    .linkLabel ==
                                                                null
                                                            ? "---"
                                                            : selectedMarker
                                                                .linkLabel
                                                                .toString(),
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const Divider(
                                                height: 1, color: Colors.grey),
                                            GestureDetector(
                                              onTap: () =>
                                                  _tabController.animateTo(2),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 18.0,
                                                    vertical: 12),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      "See photos",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
