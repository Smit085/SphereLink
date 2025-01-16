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
  String imageName;
  final List<MarkerData> markers;

  PanoramaImage(this.image, this.imageName) : markers = [];
}

class PanoramicWithMarkers extends StatefulWidget {
  const PanoramicWithMarkers({Key? key}) : super(key: key);

  @override
  State<PanoramicWithMarkers> createState() => _PanoramicWithMarkersState();
}

class _PanoramicWithMarkersState extends State<PanoramicWithMarkers> {
  final _newImageNameController = TextEditingController();
  int? _selectedIndex;
  double currentLongitude = 0.0;
  double currentLatitude = 0.0;
  int currentImageId = 0;

  final List<PanoramaImage> panoramaImages = [];
  final ImagePicker _imagePicker = ImagePicker();

  void _addMarker(double longitude, double latitude) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        List<String> imageNames =
            panoramaImages.map((image) => image.imageName).toList();
        return MarkerFormDialog(
          imageNames: imageNames,
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
          int imageName = panoramaImages.length + 1;
          panoramaImages
              .add(PanoramaImage(File(pickedImage.path), imageName.toString()));
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
      resizeToAvoidBottomInset: false,
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
              child: ReorderableListView(
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
                      key: Key('$index'),  // This key is required for reordering.
                      onTap: () {
                        setState(() {
                          currentImageId = index;
                          _selectedIndex = null;
                        });
                      },
                      onLongPress: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(
                                width: 150,
                                height: 100,
                                child: Image.file(
                                  panoramaImages[index].image,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            if (_selectedIndex == index)
                              Positioned(
                                top: 5,
                                right: 5,
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        _newImageNameController.text =
                                            panoramaImages[index].imageName;
                                        int editingIndex = index;
                                        showDialog(
                                          context: context,
                                          builder: (context) => SingleChildScrollView(
                                            child: AlertDialog(
                                              title: const Text('Edit Name'),
                                              content: ConstrainedBox(
                                                constraints: const BoxConstraints(
                                                  maxWidth: 300, // Set a maximum width for the dialog content
                                                ),
                                                child: TextFormField(
                                                  controller: _newImageNameController,
                                                  decoration: const InputDecoration(
                                                    labelText: "Enter New Name",
                                                    border: OutlineInputBorder(),
                                                  ),
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      panoramaImages[editingIndex]
                                                          .imageName =
                                                          _newImageNameController
                                                              .text;
                                                    });
                                                    Navigator.pop(context);
                                                  },
                                                  child: const Text('Save'),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.blue.withOpacity(0.7),
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(
                                          Icons.edit,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          panoramaImages.removeAt(index);
                                          _selectedIndex = null;
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.red.withOpacity(0.7),
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(
                                          Icons.delete,
                                          size: 20,
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
                  // "Add Image" button
                  GestureDetector(
                    key: const Key('add_image'),
                    onTap: () {
                      _addPanoramaImage();
                      setState(() {
                        _selectedIndex = null;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
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
