import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:custom_radio_grouped_button/custom_radio_grouped_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:panorama_viewer/panorama_viewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tuple/tuple.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/MarkerData.dart';
import '../data/PanoramaImage.dart';
import '../data/ViewData.dart';
import '../utils/RippleWaveIcon.dart';
import '../utils/appColors.dart';
import '../utils/nipPainter.dart';
import '../widget/customSnackbar.dart';
import 'PanoramaView.dart';

class PanoramaPreview extends StatefulWidget {
  final ViewData view;
  const PanoramaPreview({super.key, required this.view});

  @override
  State<PanoramaPreview> createState() => _PanoramaPreviewState();
}

class _PanoramaPreviewState extends State<PanoramaPreview>
    with SingleTickerProviderStateMixin {
  bool _isFirstLoad = false;
  bool _isLoading = false;
  int? _selectedIndex;
  late MarkerData selectedMarker;
  int currentImageId = 0;
  late List<PanoramaImage> panoramaImages = [];
  bool _isPreviewListOpen = true;
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

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    print("called");
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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: PanoramaViewer(
              key: ValueKey(Tuple4(_animationSpeed, _isAnimationEnable,
                  interactionMode.toString(), currentImageId)),
              animSpeed: _isAnimationEnable ? _animationSpeed : 0,
              animReverse: true,
              sensitivity: 1.8,
              interactive: interactionMode.contains("Touch") ? true : false,
              sensorControl: interactionMode.contains("Gyro")
                  ? SensorControl.absoluteOrientation
                  : SensorControl.none,
              hotspots: currentImage?.markers.map((marker) {
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
                          )),
                        )
                      : Opacity(
                          opacity: iconOpacity,
                          child: Transform(
                            transform: (marker.selectedIconStyle == "Flat")
                                ? (Matrix4.identity()
                                  ..rotateX(math.pi / 8)
                                  ..rotateZ(marker.selectedIconRotationRadians))
                                : (Matrix4.identity()
                                  ..rotateZ(
                                      marker.selectedIconRotationRadians)),
                            alignment: Alignment.center,
                            child: RippleWaveIcon(
                              icon: marker.selectedIcon,
                              rippleColor: marker.selectedIconColor,
                              iconSize: (iconSize == "S")
                                  ? 18
                                  : (iconSize == "M")
                                      ? 24
                                      : 32, // max: 32
                              iconColor: marker.selectedIconColor,
                              rippleDuration: const Duration(seconds: 3),
                              onTap: () {
                                setState(() {
                                  if (marker.selectedAction == "Label") {
                                    selectedMarker = marker;
                                    _tappedMarkerIndex = marker.hashCode;
                                    _closeSheetFully();
                                  }
                                });

                                if (marker.selectedAction == "Label") {
                                  _showMarkerLabel();
                                } else if (marker.selectedAction ==
                                    "Navigation") {
                                  setState(() {
                                    _selectedIndex =
                                        currentImageId = marker.nextImageId;
                                  });
                                } else if (marker.selectedAction == "Banner") {
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
              }).toList(),
              child: Image.file(currentImage!.image!),
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
                })
              },
            ),
          ),
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                top: 20,
                left: 12,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
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
                child: Row(
                  spacing: 6,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isLoading = true;
                        });
                        _showSaveDialog();
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
                        child: _isLoading
                            ? const SizedBox(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                  color: Colors.blue,
                                  strokeWidth:
                                      2, // Adjust the thickness of the indicator
                                  backgroundColor: Colors.blue,
                                ),
                              )
                            : const Center(
                                child: Icon(
                                  Icons.save_rounded,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                              ),
                      ),
                    ),
                    GestureDetector(
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
                  ],
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
                        decoration: const BoxDecoration(color: Colors.black45),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 5),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (int index = 0;
                                index < panoramaImages.length;
                                index++)
                              GestureDetector(
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
                                            child: Image.file(
                                              panoramaImages[index].image!,
                                              fit: BoxFit.cover,
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
                              ),
                          ],
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
                left: 12, // Adjusts dynamically
                child: GestureDetector(
                  onTap: currentImageId > 0
                      ? () {
                          setState(() {
                            currentImageId--;
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
                right: 12, // Adjusts dynamically
                child: GestureDetector(
                  onTap: currentImageId < panoramaImages.length - 1
                      ? () {
                          setState(() {
                            currentImageId++;
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                        const SizedBox(
                          height: 4,
                        ),
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
                              inactiveTrackColor: Colors.grey.withOpacity(0.5),
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
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                "${(_animationSpeed).toInt()}x",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
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
                                    enabledThumbRadius: 8,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 0,
                                  ),
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
                              inactiveTrackColor: Colors.grey.withOpacity(0.5),
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
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                "${(iconOpacity * 100).toInt()}%",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
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
                                    enabledThumbRadius: 8,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 0,
                                  ),
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
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                "Background Music",
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Switch(
                              padding: const EdgeInsets.all(0),
                              value: _isBgMusicEnable,
                              onChanged: (bool value) {
                                setState(() {
                                  _isBgMusicEnable = value;
                                });
                              },
                              activeColor: Colors.white,
                              activeTrackColor: Colors.white.withOpacity(0.8),
                              inactiveThumbColor: Colors.grey,
                              inactiveTrackColor: Colors.grey.withOpacity(0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Interaction Mode:",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
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
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
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
          if (_isSheetVisible)
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
                        // Drag Handle
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

                        // Header Row (Title + Icons)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title
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

                              // Icons (Share + Close)
                              Row(
                                children: [
                                  // GestureDetector(
                                  //   onTap: () {
                                  //     // TODO: Add share functionality
                                  //   },
                                  //   child: Container(
                                  //     decoration: BoxDecoration(
                                  //       shape: BoxShape.circle,
                                  //       color: Colors.grey.withOpacity(0.7),
                                  //     ),
                                  //     padding: const EdgeInsets.all(6),
                                  //     child: const Icon(
                                  //       Icons.share_rounded,
                                  //       size: 20,
                                  //       color: Colors.white,
                                  //     ),
                                  //   ),
                                  // ),
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

                        // Tabs
                        DefaultTabController(
                          length: 3,
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

                                      //Features
                                      Column(
                                        children: [
                                          Expanded(
                                            // Ensures proper rendering inside Column
                                            child: ListView(
                                              shrinkWrap:
                                                  true, // Ensures it renders inside other scrollables
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

                                      //Photos
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: MasonryGridView.count(
                                          crossAxisCount: 2,
                                          mainAxisSpacing: 8,
                                          crossAxisSpacing: 8,
                                          itemCount: selectedMarker
                                                  .bannerImage?.length ??
                                              0,
                                          itemBuilder: (context, index) {
                                            final File? imageFile =
                                                selectedMarker
                                                    .bannerImage![index];
                                            return ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Image.file(
                                                imageFile!,
                                                fit: BoxFit.cover,
                                              ),
                                            );
                                          },
                                        ),
                                      ),

                                      // About
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

                                                        // Expandable Text
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
                                                      const BoxConstraints(), // Prevents extra spacing
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
                                                  iconSize:
                                                      20, // Adjusted size for alignment
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

                                            // Divider - Now perfectly aligned with no extra space
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
                                              }, // Corrected URL format
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

  Future<String> _compressAndSaveThumbnail(
      String imagePath, String viewName) async {
    final directory = await getApplicationDocumentsDirectory();
    final thumbnailsDir = Directory('${directory.path}/thumbnails');
    if (!await thumbnailsDir.exists()) {
      await thumbnailsDir.create(recursive: true);
    }

    final thumbnailPath = '${thumbnailsDir.path}/$viewName.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      imagePath,
      thumbnailPath,
      minWidth: 512,
      minHeight: 256,
      quality: 100,
    );

    return result?.path ?? imagePath;
  }

  Future<void> _saveView(String viewName) async {
    if (panoramaImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No panorama images to save")),
      );
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final viewsDir = Directory('${directory.path}/views');
    if (!await viewsDir.exists()) {
      await viewsDir.create(recursive: true);
    }

    final originalImagePath = panoramaImages.first.image?.path;

    final thumbnailPath =
        await _compressAndSaveThumbnail(originalImagePath!, viewName);

    final newView = ViewData(
      panoramaImages: panoramaImages,
      viewName: viewName,
      thumbnailImage: File(thumbnailPath),
      dateTime: DateTime.now(),
    );

    final jsonPath = '${viewsDir.path}/$viewName.json';
    final file = File(jsonPath);
    await file.writeAsString(jsonEncode(newView.toJson()));

    if (mounted) {
      setState(() {
        panoramaImages = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _showSaveDialog() async {
    final TextEditingController nameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          actionsPadding: const EdgeInsets.all(8),
          title: Text("Save Panorama View"),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(hintText: "Enter view name"),
          ),
          actions: [
            TextButton(
              onPressed: () => {
                Navigator.of(context).pop(),
                setState(() {
                  _isLoading = false;
                })
              },
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final viewName = nameController.text.trim();
                if (viewName.isNotEmpty) {
                  _saveView(viewName);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("View name cannot be empty")),
                  );
                }
                showCustomSnackBar(context, Colors.green,
                    "New view created successfully.", Colors.white, "", null);
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: Text("Save"),
            ),
          ],
        );
      },
    ).then((_) {
      // Call setState after dialog is closed
      setState(() {
        _isLoading = false;
      });
    });
  }
}
