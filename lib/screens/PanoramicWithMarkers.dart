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
  final int nextImageId;

  MarkerData({
    required this.longitude,
    required this.latitude,
    required this.color,
    this.label = "",
    this.icon = Icons.location_pin,
    this.nextImageId = -1,
  });
}

class PanoramaImage {
  final File image;
  final List<MarkerData> markers;

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
            panoramaImages[currentImageId].markers.add(
                  MarkerData(
                    longitude: longitude,
                    latitude: latitude,
                    label: data.label,
                    icon: data.selectedIcon,
                    nextImageId: data.nextImageId,
                    color: data.iconColor,
                  ),
                  // MarkerData(
                  //     longitude: longitude,
                  //     latitude: latitude,
                  //     name: data.label,
                  //     widget: IconButton(onPressed: () {
                  //       setState(() {
                  //         currentImageId = data.nextImageId - 1;
                  //       });
                  //       print(currentImageId);
                  //       print("Btn Pressed");
                  //     }, icon: Icon(data.selectedIcon),iconSize: 43,))
                );
            print("Marker Added");
          }),
          onCancel: () => Navigator.of(context).pop(),
        );
      },
    );
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
              animReverse: true,
              sensitivity: 1.8,
              hotspots: currentImage?.markers.map((marker) {
                return Hotspot(
                  longitude: marker.longitude,
                  latitude: marker.latitude,
                  name: marker.label,
                  widget: IconButton(
                    onPressed: () {
                      print("Btn Pressed");
                      setState(() {
                        currentImageId = marker.nextImageId - 1;
                      });
                    },
                    icon: Icon(marker.icon, color: marker.color),
                    iconSize: 40,
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
                child: Center(
              child: Text(
                "No images added. Use the '+' button to add images.",
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
            )),
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
                                shape: BoxShape.circle,
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
}
