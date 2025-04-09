import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mappls_gl/mappls_gl.dart';
import 'package:spherelink/core/apiService.dart';
import 'package:spherelink/data/ViewData.dart';
import 'package:spherelink/widget/customSnackbar.dart';
import '../utils/appColors.dart';
import 'MapSelectionScreen.dart';

class PublishViewScreen extends StatefulWidget {
  final ViewData view;
  const PublishViewScreen({super.key, required this.view});

  @override
  _PublishViewScreenState createState() => _PublishViewScreenState();
}

class _PublishViewScreenState extends State<PublishViewScreen> {
  final _formKey = GlobalKey<FormState>();
  late double viewLatitude;
  late double viewLongitude;
  File? _thumbnail;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    _thumbnail = widget.view.thumbnailImage;
    _titleController.text = widget.view.viewName;
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _thumbnail = File(pickedFile.path);
      });
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
            "Lat: ${viewLatitude.toStringAsFixed(4)}°   Lng: ${viewLongitude.toStringAsFixed(4)}°";
      });
    }
  }

  Future<void> _publishView() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isPublishing = true);

      widget.view.thumbnailImage = _thumbnail!;
      widget.view.viewName = _titleController.text;
      widget.view.description = _descriptionController.text;
      widget.view.location = LatLng(viewLatitude, viewLongitude);
      widget.view.dateTime = DateTime.now();
      bool response = await ApiService().syncDataToServer(widget.view);

      if (response) {
        setState(() => _isPublishing = false);
        showCustomSnackBar(context, Colors.green,
            "View Published Successfully!", Colors.white, "", () => {});
        Navigator.pop(context);
      } else {
        setState(() => _isPublishing = false);
        showCustomSnackBar(context, Colors.red,
            "Upload failed! Please try again.", Colors.white, "", () => {});
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appprimaryBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        toolbarHeight: 60,
        backgroundColor: AppColors.appprimaryColor,
        title:
            const Text("Publish View", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => _showConfirmationDialog(context),
        ),
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
                        Image.file(
                          _thumbnail ?? File('assets/default_thumbnail.jpg'),
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                        Container(
                          color: Colors.black.withOpacity(0.3),
                        ),
                        Center(
                          // Center the Column
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.camera_alt,
                                  size: 40, color: Colors.white),
                              const SizedBox(height: 10),
                              Text(
                                "Tap to change the thumbnail",
                                style: GoogleFonts.lato(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
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
                  labelStyle: TextStyle(),
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? "Please enter a description" : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isPublishing ? null : _publishView,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textColorPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isPublishing
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ))
                      : const Icon(Icons.file_upload_outlined,
                          size: 24, color: Colors.white),
                  label: Text(
                    _isPublishing ? "Publishing..." : "Publish View",
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
            "Are you sure you want to go back without publishing this view?",
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
