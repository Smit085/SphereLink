import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:panorama_viewer/panorama_viewer.dart';

import '../utils/MarkerFormDialog.dart';

class MarkerData {
  double longitude;
  double latitude;
  final String label;
  final IconData icon;
  final Color color;
  final int nextImage;

  MarkerData(this.longitude, this.latitude, this.nextImage,
      {this.label = "",
        this.icon = Icons.location_pin,
        this.color = Colors.red});
}

class PanoramaImage {
  final File image;
  final List<MarkerData> markers;
  final List<Hotspot> hotspots = [];

  PanoramaImage(this.image) : markers = [];
}

class PanoramicWithMarkers extends StatefulWidget {
  const PanoramicWithMarkers({Key? key}) : super(key: key);

  @override
  State<PanoramicWithMarkers> createState() => _PanoramicWithMarkersState();
}

class _PanoramicWithMarkersState extends State<PanoramicWithMarkers> {
  double currentLongitude = 0.0;
  double currentLatitude = 0.0;
  int currentImageId = 0;

  final List<PanoramaImage> panoramaImages = [];
  final ImagePicker _imagePicker = ImagePicker();

  void _addMarker(double longitude, double latitude) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return MarkerFormDialog(
          panoramaImages.length,
          onSave: (data) => setState(() {
            panoramaImages[currentImageId].hotspots.add(
                Hotspot(
                    longitude: longitude,
                    latitude: latitude,
                    name: data.label,
                    widget: IconButton(onPressed: () {
                      setState(() {
                        currentImageId = data.nextImageId - 1;
                      });
                      print(currentImageId);
                      print("Btn Pressed");
                    }, icon: Icon(data.selectedIcon),iconSize: 43,))
            );
            print("Marker Added");
          }),
          onCancel: () => Navigator.of(context).pop(),
        );
      },
    );

    // showDialog(
    //   barrierDismissible: true,
    //   context: context,
    //   builder: (BuildContext context) {
    //     return MarkerFormDialog(
    //       panoramaImages.length,
    //       onSave: (data) => print('Data saved: $data'),
    //       onCancel: () => Navigator.of(context).pop(),
    //     );
    //   },
    // );
  }

  void _deleteMarker(MarkerData marker) {
    setState(() {
      panoramaImages[currentImageId].markers.remove(marker);
    });
  }

  Future<void> _addPanoramaImage() async {
    final List<XFile>? pickedImages = await _imagePicker.pickMultiImage();

    if (pickedImages != null && pickedImages.isNotEmpty) {
      setState(() {
        for (var pickedImage in pickedImages) {
          panoramaImages.add(PanoramaImage(File(pickedImage.path)));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentImage =
    panoramaImages.isNotEmpty ? panoramaImages[currentImageId] : null;
    final currentMarkers = currentImage?.markers ?? [];
    return Scaffold(
      body: Stack(
        children: [
          if (panoramaImages.isNotEmpty)
            PanoramaViewer(
              hotspots: panoramaImages[currentImageId].hotspots,
              animReverse: true,
              sensitivity: 1.8,
              child: Image.file(currentImage!.image),
              onViewChanged: (longitude, latitude, tilt) {
                setState(() {
                  currentLongitude = longitude;
                  currentLatitude = latitude;
                });
              },
              onTap: (longitude, latitude, tilt) {
                setState(() {
                  currentLongitude = longitude;
                  currentLatitude = latitude;
                });
                _addMarker(longitude, latitude);
              },
            )
          else
            const Center(
              child: Text(
                "No images added. Use the '+' button to add images.",
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
            ),
          Stack(
            children: currentMarkers.map((marker) {
              final screenPos =
              _getScreenPosition(marker.longitude, marker.latitude);
              if (screenPos == null) {
                return const SizedBox.shrink();
              }
              return Positioned(
                left: screenPos.dx - 20,
                top: screenPos.dy - 30,
                child: GestureDetector(
                  onTap: () {
                  },
                  onLongPress: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Marker Options"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(marker.label),
                            TextButton(
                              onPressed: () {
                                _deleteMarker(marker);
                                Navigator.pop(context);
                              },
                              child: const Text("Delete"),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: IconButton(
                    onPressed: () {
                      print("Change");
                      setState(() {
                        if (marker.nextImage <= panoramaImages.length) {
                          currentImageId = marker.nextImage - 1;
                        }
                      });
                    },
                    icon: const Icon(
                      Icons.arrow_circle_up,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 100,
              color: Colors.black.withOpacity(0.5),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: panoramaImages.length + 1,
                itemBuilder: (context, index) {
                  if (index == panoramaImages.length) {
                    // "Add Image" button
                    return GestureDetector(
                      onTap: _addPanoramaImage,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          width: 100,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.add_circle_outline,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        currentImageId = index;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 100,
                              height: 100,
                              child: Image.file(
                                panoramaImages[index].image,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(140),
                                shape: BoxShape
                                    .circle,
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
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
    );
  }

  Offset? _getScreenPosition(double markerLongitude, double markerLatitude) {
    double diffLongitude = markerLongitude - currentLongitude;
    double diffLatitude = markerLatitude - currentLatitude;

    while (diffLongitude > 180) diffLongitude -= 360;
    while (diffLongitude < -180) diffLongitude += 360;

    double screenX = (diffLongitude / 180) * MediaQuery.of(context).size.width +
        MediaQuery.of(context).size.width / 2;
    double screenY =
        (-diffLatitude / 120) * MediaQuery.of(context).size.height +
            MediaQuery.of(context).size.height / 2;

    if (screenX < 0 ||
        screenX > MediaQuery.of(context).size.width ||
        screenY < 0 ||
        screenY > MediaQuery.of(context).size.height) {
      return null;
    }

    return Offset(screenX, screenY);
  }
}
