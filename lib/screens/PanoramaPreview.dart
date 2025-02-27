import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:custom_radio_grouped_button/custom_radio_grouped_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:panorama_viewer/panorama_viewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tuple/tuple.dart';

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

class _PanoramaPreviewState extends State<PanoramaPreview> {
  bool _isFirstLoad = false;
  bool _isLoading = false;
  int? _selectedIndex;
  MarkerData? selectedMarker;
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

  void initializeView() {
    panoramaImages = widget.view.panoramaImages;
  }

  @override
  void initState() {
    super.initState();
    initializeView();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _showMarkerLabel(MarkerData marker) {
    setState(() {
      selectedMarker = marker;
    });
    Future.delayed(const Duration(seconds: 20), () {
      setState(() {
        selectedMarker = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    final currentImage =
        panoramaImages.isNotEmpty ? panoramaImages[currentImageId] : null;

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
                  longitude: marker.longitude,
                  latitude: marker.latitude,
                  name: marker.label,
                  widget: Opacity(
                    opacity: iconOpacity,
                    child: Transform(
                      transform: (marker.selectedIconStyle == "Flat")
                          ? (Matrix4.identity()
                            ..rotateX(math.pi / 8)
                            ..rotateZ(marker.selectedIconRotationRadians))
                          : (Matrix4.identity()
                            ..rotateZ(marker.selectedIconRotationRadians)),
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
                          switch (marker.selectedAction) {
                            case "Navigation":
                              setState(() {
                                _selectedIndex =
                                    currentImageId = marker.nextImageId;
                              });
                            case "Label":
                              _showMarkerLabel(marker);
                            case "Banner":
                              _showMarkerLabel(marker);
                          }
                        },
                      ),
                    ),
                  ),
                );
              }).toList(),
              child: Image.file(currentImage!.image),
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
          if (selectedMarker != null)
            Positioned(
              left: MediaQuery.of(context).orientation == Orientation.landscape
                  ? MediaQuery.of(context).size.width / 1.40
                  : MediaQuery.of(context).size.width / .40,
              top: MediaQuery.of(context).size.height / 25,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    top: 12,
                    left: -14.5,
                    child: Transform.rotate(
                      angle: -90 * math.pi / 180,
                      child: CustomPaint(
                        painter: NipPainter(
                          borderColor: Colors.white.withAlpha(150),
                        ),
                        child: const SizedBox(
                          width: 20,
                          height: 10,
                        ),
                      ),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                      child: Container(
                        width: MediaQuery.of(context).size.width / 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(120),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: Colors.white.withAlpha(150),
                            width: 1.5,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width / 2,
                            maxHeight: MediaQuery.of(context).size.height / 2,
                          ),
                          child: SingleChildScrollView(
                              child: Stack(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (selectedMarker?.bannerImage != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: SizedBox(
                                        height: 100,
                                        child: selectedMarker?.bannerImage !=
                                                null
                                            ? Image.file(
                                                selectedMarker!.bannerImage!,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                // Placeholder widget
                                                color: Colors.grey[200],
                                                child: const Center(
                                                    child: Icon(Icons.image,
                                                        color: Colors.grey)),
                                              ),
                                      ),
                                    ),
                                  const SizedBox(
                                    height: 15,
                                  ),
                                  Flexible(
                                    child: Text(
                                      selectedMarker!.label,
                                      style: GoogleFonts.tinos(
                                        height: 1.2,
                                        color: Colors.black,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ).copyWith(
                                          color: Colors.black.withAlpha(160)),
                                      softWrap: true,
                                    ),
                                  ),
                                  if (selectedMarker?.description != "")
                                    const Divider(
                                        height: 2, color: Colors.black12),
                                  if (selectedMarker?.description != "")
                                    Flexible(
                                      child: Text(
                                        selectedMarker!.description,
                                        style: GoogleFonts.abhayaLibre(
                                            color: Colors.black87, height: 1.2),
                                        softWrap: true,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          )),
                        ),
                      ),
                    ),
                  ),
                ],
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
                                              panoramaImages[index].image,
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
                                  min: 0.0,
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
          )
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

    final originalImagePath = panoramaImages.first.image.path;

    final thumbnailPath =
        await _compressAndSaveThumbnail(originalImagePath, viewName);

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
