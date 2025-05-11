import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:panorama_viewer/panorama_viewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:spherelink/screens/PanoramaPreview.dart';
import 'package:tuple/tuple.dart';
import 'package:spherelink/utils/mergeImages.dart';
import 'package:spherelink/widget/customSnackbar.dart';

import '../data/MarkerData.dart';
import '../data/PanoramaImage.dart';
import '../data/ViewData.dart';
import '../utils/appColors.dart';
import '../utils/markerFormDialog.dart';

class PanoramicWithMarkers extends StatefulWidget {
  const PanoramicWithMarkers({super.key});

  @override
  State<PanoramicWithMarkers> createState() => _PanoramicWithMarkersState();
}

class _PanoramicWithMarkersState extends State<PanoramicWithMarkers> {
  final _newImageNameController = TextEditingController();
  bool _isFirstLoad = false;
  int? _selectedIndex;
  MarkerData? selectedMarker;
  double currentLongitude = 0.0;
  double currentLatitude = 0.0;
  int currentImageId = 0;
  bool _isLoading = false;
  bool _isPreviewListOpen = true;
  bool _isSettingsOpen = false;
  late bool _isAnimationEnable = false;
  late bool _showHotspots = true;
  late bool _isBgMusicEnable = false;
  List<String> interactionMode = ["Touch"];
  String viewModes = "Phone";
  double iconOpacity = 1;
  double _animationSpeed = 1;

  late List<PanoramaImage> panoramaImages = [];
  final ImagePicker _imagePicker = ImagePicker();

  // List<ViewData> savedViews = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _saveView(String viewName) async {
    if (panoramaImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No panorama images to save")),
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

  Future<void> _showSaveDialog() async {
    final TextEditingController nameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.appprimaryBackgroundColor,
          actionsPadding: const EdgeInsets.all(8),
          title: const Text("Save Your Tour"),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: "Enter view name"),
          ),
          actions: [
            TextButton(
              onPressed: () => {
                Navigator.of(context).pop(),
                setState(() {
                  _isLoading = false;
                })
              },
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.appprimaryBackgroundColor,
              ),
              onPressed: () {
                final viewName = nameController.text.trim();
                if (viewName.isNotEmpty) {
                  _saveView(viewName);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("View name cannot be empty")),
                  );
                }
                showCustomSnackBar(context, Colors.green,
                    "New view created successfully.", Colors.white, "", null);
                Navigator.of(context).pop();
              },
              child: const Text(
                "Save",
                style: TextStyle(color: Colors.blue),
              ),
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

  void _addMarker(double longitude, double latitude) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        List<String> imageNames =
            panoramaImages.map((image) => image.imageName).toList();
        return MarkerFormDialog(
          title: "Add",
          imageNames: imageNames,
          onSave: (data) => setState(() {
            panoramaImages[currentImageId].markers.add(
                  MarkerData(
                      link: data.link,
                      linkLabel: data.linkLabel,
                      bannerImage: data.bannerImage,
                      longitude: longitude,
                      latitude: latitude,
                      label: data.label,
                      subTitle: data.subTitle,
                      selectedIcon: data.selectedIcon,
                      selectedIconStyle: data.selectedIconStyle,
                      selectedIconRotationRadians:
                          data.selectedIconRotationRadians,
                      nextImageId: data.nextImageId,
                      selectedIconColor: data.selectedIconColor,
                      selectedAction: data.selectedAction,
                      description: data.description,
                      address: data.address,
                      phoneNumber: data.phoneNumber),
                );
            print("Marker Added");
          }),
          onCancel: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  void _onEditMarker(MarkerData markerData) {
    List<String> imageNames =
        panoramaImages.map((image) => image.imageName).toList();
    showDialog(
      context: context,
      builder: (context) {
        return MarkerFormDialog(
          title: "Edit",
          initialData: markerData,
          imageNames: imageNames,
          onSave: (updatedMarkerData) {
            setState(() {
              selectedMarker?.selectedAction = updatedMarkerData.selectedAction;
              selectedMarker?.selectedIcon = updatedMarkerData.selectedIcon;
              selectedMarker?.selectedIconStyle =
                  updatedMarkerData.selectedIconStyle;
              selectedMarker?.selectedIconRotationRadians =
                  updatedMarkerData.selectedIconRotationRadians;
              selectedMarker?.selectedIconColor =
                  updatedMarkerData.selectedIconColor;
              selectedMarker?.label = updatedMarkerData.label;
              selectedMarker?.description = updatedMarkerData.description;
              selectedMarker?.address = updatedMarkerData.address;
              selectedMarker?.phoneNumber = updatedMarkerData.phoneNumber;
              selectedMarker?.nextImageId = updatedMarkerData.nextImageId;
              selectedMarker?.link = updatedMarkerData.link;
              selectedMarker?.linkLabel = updatedMarkerData.linkLabel;
              selectedMarker?.bannerImage = updatedMarkerData.bannerImage;
            });
          },
          onDelete: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
                  backgroundColor: AppColors.appsecondaryColor,
                  title: const Text(
                    "Confirm Delete",
                    style: TextStyle(color: Colors.white),
                  ),
                  content: const Text(
                    "Are you sure you want to delete this marker?",
                    style: TextStyle(color: Colors.white),
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                            color: Colors.lightBlueAccent,
                            fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        setState(() {
                          panoramaImages[currentImageId]
                              .markers
                              .remove(selectedMarker);
                        });
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        "Delete",
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showBottomSheetForImage() {
    showModalBottomSheet(
      backgroundColor: AppColors.appprimaryBackgroundColor,
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.add_rounded), // Optional icon
                title: const Text('Add 360 Image'),
                onTap: () {
                  _addPanoramaImage();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.merge_rounded),
                title: const Text('Merge and add two Panorama images'),
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
  }

  Future<void> _addPanoramaImage() async {
    final List<XFile> pickedImages = await _imagePicker.pickMultiImage();

    if (pickedImages.isNotEmpty) {
      setState(() {
        for (var pickedImage in pickedImages) {
          int imageName = panoramaImages.length + 1;
          panoramaImages.add(
              PanoramaImage(File(pickedImage.path), "", imageName.toString()));
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
                .add(PanoramaImage(mergedImageFile, "", imageName.toString()));
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                duration: Duration(milliseconds: 800),
                content: Text('Images merged successfully.')),
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
              duration: const Duration(milliseconds: 800),
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
    MediaQuery.of(context).orientation == Orientation.landscape
        ? SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)
        : SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    final currentImage =
        panoramaImages.isNotEmpty ? panoramaImages[currentImageId] : null;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.appprimaryBackgroundColor,
      body: Stack(
        children: [
          if (panoramaImages.isNotEmpty)
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
                      child: IconButton(
                        onPressed: () {
                          setState(() {
                            selectedMarker = marker;
                          });
                          _onEditMarker(selectedMarker!);
                        },
                        icon: Transform(
                          transform: (marker.selectedIconStyle == "Flat")
                              ? (Matrix4.identity()
                                ..rotateX(math.pi / 8)
                                ..rotateZ(marker.selectedIconRotationRadians))
                              : (Matrix4.identity()
                                ..rotateZ(marker.selectedIconRotationRadians)),
                          child: Icon(marker.selectedIcon,
                              color: marker.selectedIconColor),
                        ),
                        iconSize: 35,
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
              ),
            )
          else
            Center(
              heightFactor:
                  MediaQuery.of(context).orientation == Orientation.portrait
                      ? double.infinity
                      : 1.5,
              child: GestureDetector(
                onTap: () {
                  _showBottomSheetForImage();
                  setState(() {
                    _selectedIndex = null;
                  });
                },
                child: DottedBorder(
                  borderType: BorderType.RRect,
                  dashPattern: const [12, 4],
                  strokeWidth: 2,
                  color: Colors.grey,
                  radius: const Radius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    width: 300,
                    height: 200,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          size: 80,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          textAlign: TextAlign.center,
                          "Add image in the slider to get started.",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Stack(alignment: Alignment.bottomCenter, children: [
            Positioned(
              top: 20,
              left: 12,
              child: GestureDetector(
                onTap: () {
                  panoramaImages.isNotEmpty
                      ? _showConfirmationDialog(context)
                      : Navigator.of(context).pop();
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
            if (panoramaImages.isNotEmpty)
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
                                  strokeWidth: 2,
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
                        final newView = ViewData(
                          panoramaImages: panoramaImages,
                          viewName: "",
                          thumbnailImage: File(""),
                          dateTime: DateTime.now(),
                        );
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    PanoramaPreview(view: newView)));
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
                            Icons.remove_red_eye_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                      ),
                    )
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
                      child: ReorderableListView(
                        proxyDecorator: (Widget child, int index,
                            Animation<double> animation) {
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
                          for (int index = 0;
                              index < panoramaImages.length;
                              index++)
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
                                          width: _selectedIndex == index
                                              ? 2.0
                                              : 0.0,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: SizedBox(
                                          width: 120,
                                          height: 120,
                                          child: Image.file(
                                            panoramaImages[index].image!,
                                            fit: BoxFit.cover,
                                          ),
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
                                                    panoramaImages[index]
                                                        .imageName;
                                                int editingIndex = index;
                                                showDialog(
                                                  context: context,
                                                  builder: (context) =>
                                                      SingleChildScrollView(
                                                    child: AlertDialog(
                                                      actionsPadding:
                                                          const EdgeInsets.all(
                                                              8),
                                                      title: const Text(
                                                          'Edit Name'),
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
                                                            labelText:
                                                                "Enter New Name",
                                                            border:
                                                                OutlineInputBorder(),
                                                          ),
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context),
                                                          child: const Text(
                                                              'Cancel'),
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
                                                            Navigator.pop(
                                                                context);
                                                          },
                                                          child: const Text(
                                                              'Save'),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.blue
                                                      .withOpacity(0.7),
                                                ),
                                                padding:
                                                    const EdgeInsets.all(4),
                                                child: const Icon(
                                                  Icons.edit,
                                                  size: 15,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
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
                                                  Icons.delete,
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
                                          maxWidth: 140,
                                        ),
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
                              _showBottomSheetForImage();
                              setState(() {
                                _selectedIndex = null;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Container(
                                width: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.add_circle_outline,
                                    size: 30,
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
              // Adjusts dynamically
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
                      color:
                          currentImageId > 0 ? Colors.white70 : Colors.white12,
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
              // Adjusts dynamically
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
          ]),
        ],
      ),
    );
  }

  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
          backgroundColor: AppColors.appsecondaryColor,
          title: const Text(
            "Confirm",
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            "Are you sure you want to go back without saving this view?",
            style: TextStyle(color: Colors.white),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                "No",
                style: TextStyle(
                    color: Colors.lightBlueAccent, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text(
                "Yes",
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
