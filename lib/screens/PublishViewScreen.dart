import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spherelink/core/apiService.dart';
import 'package:spherelink/core/session.dart';
import 'package:spherelink/data/ViewData.dart';
import 'package:spherelink/widget/customSnackbar.dart';
import '../core/AppConfig.dart';
import '../utils/appColors.dart';
import 'MapSelectionScreen.dart';
import 'package:image/image.dart' as img;

class PublishViewScreen extends StatefulWidget {
  final ViewData view;
  const PublishViewScreen({super.key, required this.view});

  @override
  _PublishViewScreenState createState() => _PublishViewScreenState();
}

class _PublishViewScreenState extends State<PublishViewScreen> {
  final _formKey = GlobalKey<FormState>();
  late double? viewLatitude;
  late double? viewLongitude;
  File? _thumbnail;
  String? _thumbnailUrl;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isProcessing = false;
  bool get _isEditMode => widget.view.viewId != null;

  @override
  void initState() {
    super.initState();
    _thumbnail = widget.view.thumbnailImage;
    _thumbnailUrl = widget.view.thumbnailImageUrl;
    _titleController.text = widget.view.viewName ?? '';
    _descriptionController.text = widget.view.description ?? '';
    viewLatitude = widget.view.latitude;
    viewLongitude = widget.view.longitude;
    _locationController.text = viewLatitude != null && viewLongitude != null
        ? "Lat: ${viewLatitude!.toStringAsFixed(4)}°   Lng: ${viewLongitude!.toStringAsFixed(4)}°"
        : '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<File?> _resizeImage(File image) async {
    final bytes = await image.readAsBytes();
    final imageData = img.decodeImage(bytes)!;
    final resized = img.copyResize(imageData, width: 400);
    final resizedFile = File(image.path)
      ..writeAsBytesSync(img.encodeJpg(resized, quality: 85));
    return resizedFile;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        File? image = File(pickedFile.path);
        image = await _resizeImage(image);
        setState(() {
          _thumbnail = image;
        });
      }
    } catch (e) {
      showCustomSnackBar(
          context, Colors.red, "Failed to pick image", Colors.white, "", () {});
    }
  }

  Future<void> _selectLocation() async {
    final selectedLocation = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MapSelectionScreen(),
      ),
    );

    if (selectedLocation != null && selectedLocation is Map<String, double>) {
      setState(() {
        viewLatitude = selectedLocation['latitude']!;
        viewLongitude = selectedLocation['longitude']!;
        _locationController.text =
            "Lat: ${viewLatitude!.toStringAsFixed(4)}°   Lng: ${viewLongitude!.toStringAsFixed(4)}°";
      });
    }
  }

  Future<String?> LatLongToAddress(double latitude, double longitude) async {
    List<Placemark> placemarks = await placemarkFromCoordinates(
      latitude,
      longitude,
    );
    if (placemarks.isNotEmpty) {
      Placemark placemark = placemarks[0];
      return "${placemark.locality}, ${placemark.administrativeArea}";
    } else {
      return null;
    }
  }

  Future<void> _processView() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);
    try {
      bool success;
      widget.view.thumbnailImage = _thumbnail;
      widget.view.viewName = _titleController.text;
      widget.view.description = _descriptionController.text;
      widget.view.latitude = viewLatitude;
      widget.view.longitude = viewLongitude;
      widget.view.dateTime = DateTime.now();
      String? firstName = await Session().getFirstName();
      String? lastName = await Session().getLastName();
      widget.view.creatorName = "$firstName $lastName";
      widget.view.cityName =
          await LatLongToAddress(viewLatitude!, viewLongitude!);
      widget.view.creatorProfileImagePath =
          await Session().getProfileImagePath();

      if (_isEditMode) {
        success = await ApiService().updateView(
          viewId: widget.view.viewId!,
          viewName: _titleController.text,
          description: _descriptionController.text,
          latitude: viewLatitude,
          longitude: viewLongitude,
          thumbnailImage: _thumbnail,
        );
      } else {
        if (_thumbnail == null) {
          showCustomSnackBar(context, Colors.red, "Please select a thumbnail",
              Colors.white, "", () {});
          setState(() => _isProcessing = false);
          return;
        }
        success = await ApiService().publishView(widget.view);
      }

      if (success) {
        showCustomSnackBar(
            context,
            Colors.green,
            _isEditMode
                ? "View updated successfully"
                : "View published successfully",
            Colors.white,
            "",
            () {});
        Navigator.pop(context, true);
      } else {
        showCustomSnackBar(
            context,
            Colors.red,
            _isEditMode ? "Failed to update view" : "Failed to publish view",
            Colors.white,
            "",
            () {});
      }
    } catch (e) {
      print("Failed to process view: $e");
      showCustomSnackBar(context, Colors.red, "Something went wrong!",
          Colors.white, "", () {});
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _shareView() {
    if (widget.view.viewId == null) {
      showCustomSnackBar(context, Colors.red, "Cannot share: Invalid view ID",
          Colors.white, "", () {});
      return;
    }
    final shareUrl = "http://192.168.126.30:8080/views/${widget.view.viewId}";
    // Share.share('Check out my view: $shareUrl', subject: 'Share View');
  }

  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        );
      },
    );
  }

  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
          backgroundColor: AppColors.appsecondaryColor,
          title: const Text("Confirm", style: TextStyle(color: Colors.white)),
          content: Text(
            _isEditMode
                ? "Are you sure you want to go back without saving changes?"
                : "Are you sure you want to go back without publishing this view?",
            style: const TextStyle(color: Colors.white),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("No",
                  style: TextStyle(
                      color: Colors.lightBlueAccent,
                      fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text("Yes",
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appprimaryBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        toolbarHeight: 60,
        backgroundColor: AppColors.appprimaryColor,
        title: Text(
          _isEditMode ? "Edit View" : "Publish View",
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => _showConfirmationDialog(context),
        ),
        actions: _isEditMode
            ? [
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: _shareView,
                  tooltip: 'Share View',
                ),
              ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _showImagePickerDialog,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.textColorPrimary.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        _thumbnail != null
                            ? Image.file(
                                _thumbnail!,
                                width: double.infinity,
                                height: 180,
                                fit: BoxFit.cover,
                              )
                            : widget.view.thumbnailImageUrl != null
                                ? Image.network(
                                    widget.view.thumbnailImageUrl!,
                                    width: double.infinity,
                                    height: 180,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Image.asset(
                                                'assets/image_load_failed.png'),
                                  )
                                : Image.asset(
                                    'assets/default_thumbnail.jpg',
                                    width: double.infinity,
                                    height: 180,
                                    fit: BoxFit.cover,
                                  ),
                        Container(
                          color: Colors.black.withOpacity(0.3),
                        ),
                        const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt,
                                  size: 40, color: Colors.white),
                              SizedBox(height: 10),
                              Text(
                                "Tap to change the thumbnail",
                                style: TextStyle(
                                    fontSize: 14, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                maxLength: 100,
                decoration: const InputDecoration(
                  counterText: '',
                  labelText: "View Title",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? "Please enter a title" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                onTap: _selectLocation,
                controller: _locationController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: "Location",
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.my_location),
                    onPressed: _selectLocation,
                  ),
                ),
                validator: (value) =>
                    value!.isEmpty ? "Please select a location" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: _descriptionController,
                maxLines: 5,
                maxLength: 800,
                decoration: const InputDecoration(
                  alignLabelWithHint: true,
                  labelText: "Description",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? "Please enter a description" : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _processView,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textColorPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _isEditMode ? Icons.save : Icons.file_upload_outlined,
                          size: 24,
                          color: Colors.white,
                        ),
                  label: Text(
                    _isProcessing
                        ? (_isEditMode ? "Saving..." : "Publishing...")
                        : (_isEditMode ? "Save Changes" : "Publish View"),
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
