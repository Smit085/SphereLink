import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:balloon_widget/balloon_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:panorama_viewer/panorama_viewer.dart';
import 'package:spherelink/utils/mergeImages.dart';

import '../utils/markerFormDialog.dart';
import '../utils/nipPainter.dart';

class MarkerData {
  double longitude;
  double latitude;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final int nextImageId;
  String action;
  File? bannerImage;

  MarkerData({
    required this.description,
    required this.action,
    required this.longitude,
    required this.latitude,
    required this.color,
    this.label = "",
    this.icon = Icons.location_pin,
    this.nextImageId = -1,
    this.bannerImage
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
  MarkerData? selectedMarker;
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
                    action: data.selectedAction,
                    description: data.description,
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

  void _showMarkerLabel(MarkerData marker) {
    setState(() {
      selectedMarker = marker; // Update selected marker
    });
    Future.delayed(const Duration(seconds: 20), () {
      setState(() {
        selectedMarker = null; // Hide balloon after a delay
      });
    });
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

  Future<void> _addMergedPanoramaImages() async {
    final List<XFile> pickedImages = await _imagePicker.pickMultiImage(
      limit: 2,
    );

    if (pickedImages.length == 2) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text("Processing..."),
                ],
              ),
            ),
          );
        },
      );

      try {
        File? mergedImageFile = await mergeImages(pickedImages, context);

        Navigator.of(context).pop();

        if (mergedImageFile != null) {
          setState(() {
            int imageName = panoramaImages.length + 1;
            panoramaImages
                .add(PanoramaImage(mergedImageFile, imageName.toString()));
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                duration: Duration(milliseconds: 800),
                content: Text('Images successfully merged.')),
          );
        } else {
          // Show an error message if merging failed
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                duration: Duration(milliseconds: 800),
                content: Text('Failed to merge images. Please try again.')),
          );
        }
      } catch (e) {
        // Dismiss the dialog and handle any errors
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              duration: Duration(milliseconds: 800),
              content: Text('An error occurred: $e')),
        );
      }
    } else {
      // Inform the user to select exactly two images
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            duration: Duration(milliseconds: 800),
            content: Text('Please select exactly two images to merge.')),
      );
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
                      switch (marker.action) {
                        case "Navigation":
                          setState(() {
                            currentImageId = marker.nextImageId - 1;
                          });
                        case "Label":
                          _showMarkerLabel(marker);
                        case "Banner":
                          _showMarkerLabel(marker);
                      }
                    },
                    icon: Icon(marker.icon, color: marker.color),
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
          if (selectedMarker != null)
            Positioned(
              left: MediaQuery.of(context).size.width / 1.40,
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: SizedBox(
                                    height: 100,
                                    child: selectedMarker?.bannerImage != null
                                        ? Image.file(
                                      selectedMarker!.bannerImage!,
                                      fit: BoxFit.cover,
                                    )
                                        : Container( // Placeholder widget
                                      color: Colors.grey[200],
                                      child: const Center(child: Icon(Icons.image, color: Colors.grey)),
                                    ),
                                  ),
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
                                    height: 2,
                                    color: Colors.black12,
                                  ),
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
                          ),
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
                      // onLongPress: () {
                      //   setState(() {
                      //     _selectedIndex = index;
                      //   });
                      // },
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
                                          builder: (context) =>
                                              SingleChildScrollView(
                                            child: AlertDialog(
                                              title: const Text('Edit Name'),
                                              content: ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                  maxWidth:
                                                      300, // Set a maximum width for the dialog content
                                                ),
                                                child: TextFormField(
                                                  controller:
                                                      _newImageNameController,
                                                  decoration:
                                                      const InputDecoration(
                                                    labelText: "Enter New Name",
                                                    border:
                                                        OutlineInputBorder(),
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
                                                      panoramaImages[
                                                                  editingIndex]
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
                  GestureDetector(
                    key: const Key('add_image'),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (BuildContext context) {
                          return SafeArea(
                            child: Wrap(
                              children: [
                                ListTile(
                                  leading:
                                      const Icon(Icons.add), // Optional icon
                                  title: const Text('Add 360 Image'),
                                  onTap: () {
                                    _addPanoramaImage();
                                    Navigator.pop(context);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.remove),
                                  title: const Text(
                                      'Merge and add two Panorama images'),
                                  onTap: () {
                                    _addMergedPanoramaImages();
                                    Navigator.pop(context);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
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
