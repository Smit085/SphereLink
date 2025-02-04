import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:panorama_viewer/panorama_viewer.dart';

import '../data/MarkerData.dart';
import '../data/PanoramaImage.dart';
import '../data/ViewData.dart';
import '../utils/appColors.dart';
import '../utils/nipPainter.dart';

class PanoramaView extends StatefulWidget {
  final ViewData view;
  const PanoramaView({super.key, required this.view});

  @override
  State<PanoramaView> createState() => _PanoramaViewState();
}

class _PanoramaViewState extends State<PanoramaView> {
  int? _selectedIndex;
  MarkerData? selectedMarker;
  double currentLongitude = 0.0;
  double currentLatitude = 0.0;
  int currentImageId = 0;
  late List<PanoramaImage> panoramaImages = [];

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
          PanoramaViewer(
            animReverse: true,
            sensitivity: 1.8,
            hotspots: currentImage?.markers.map((marker) {
              return Hotspot(
                longitude: marker.longitude,
                latitude: marker.latitude,
                name: marker.label,
                widget: IconButton(
                  onPressed: () {
                    switch (marker.selectedAction) {
                      case "Navigation":
                        setState(() {
                          _selectedIndex = null;
                          currentImageId = marker.nextImageId;
                        });
                      case "Label":
                        setState(() {
                          _selectedIndex = null;
                        });
                        _showMarkerLabel(marker);
                      case "Banner":
                        setState(() {
                          _selectedIndex = null;
                        });
                        _showMarkerLabel(marker);
                    }
                  },
                  icon: Icon(marker.selectedIcon,
                      color: marker.selectedIconColor),
                  iconSize: 35,
                ),
              );
            }).toList(),
            child: Image.file(currentImage!.image),
            onViewChanged: (longitude, latitude, tilt) {
              setState(() {
                currentLongitude = longitude;
                currentLatitude = latitude;
              });
            },
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
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 100,
              color: Colors.black.withOpacity(0.5),
              child: ReorderableListView(
                proxyDecorator:
                    (Widget child, int index, Animation<double> animation) {
                  return Material(
                    color: Colors.transparent,
                    child: child,
                  );
                },
                scrollDirection: Axis.horizontal,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final item = panoramaImages.removeAt(oldIndex);
                    panoramaImages.insert(newIndex, item);
                  });
                },
                children: [
                  for (int index = 0; index < panoramaImages.length; index++)
                    GestureDetector(
                      key: Key('$index'),
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
                                  width: _selectedIndex == index ? 2.0 : 0.0,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: SizedBox(
                                  width: 150,
                                  height: 100,
                                  child: Image.file(
                                    panoramaImages[index].image,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 5,
                              left: 5,
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 140,
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(140),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  panoramaImages[index].imageName.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
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
    );
  }
}
