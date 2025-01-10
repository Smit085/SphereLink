import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class MarkerFormData {
  IconData selectedIcon;
  String label;
  String description;
  String? link;
  File? image;

  MarkerFormData({
    required this.selectedIcon,
    required this.label,
    required this.description,
    this.link,
    this.image,
  });
}

class MarkerFormDialog extends StatefulWidget {
  final Function(MarkerFormData) onSave;
  final VoidCallback onCancel;

  const MarkerFormDialog(
      {Key? key, required this.onSave, required this.onCancel})
      : super(key: key);

  @override
  State<MarkerFormDialog> createState() => _MarkerFormDialogState();
}

class _MarkerFormDialogState extends State<MarkerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  IconData _selectedIcon = Icons.location_on;
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  File? _image;
  final ImagePicker _picker = ImagePicker();

  // List of available icons
  static List<IconData> iconOptions = [
    Icons.location_on,
    Icons.info,
    Icons.shopping_cart,
    Icons.restaurant,
    Icons.hotel,
    Icons.local_parking,
  ];

  @override
  void dispose() {
    _labelController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      }
    });
  }

  Future<void> _pickImageFromCamera() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.camera);
    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
      title: const Text("Add Marker",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w200)),
      content: SingleChildScrollView(
          child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Selection
              DropdownButton<IconData>(
                value: _selectedIcon,
                items: iconOptions.map((IconData value) {
                  return DropdownMenuItem<IconData>(
                    value: value,
                    child: Row(
                      children: [
                        Icon(value),
                        const SizedBox(width: 4),
                        Text(value.toString().split('.').last),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (IconData? newValue) {
                  setState(() {
                    _selectedIcon = newValue ?? Icons.location_on;
                  });
                },
              ),
              TextFormField(
                maxLength: 20,
                controller: _labelController,
                decoration: const InputDecoration(
                    labelText: "Add Name", labelStyle: TextStyle(fontSize: 12)),
                style: const TextStyle(fontSize: 14),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a label';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                maxLength: 50,
                decoration: const InputDecoration(
                    labelText: "Add Description",
                    labelStyle: TextStyle(fontSize: 12)),
                style: const TextStyle(fontSize: 14),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _linkController,
                decoration: const InputDecoration(
                    labelText: "Add Link", labelStyle: TextStyle(fontSize: 12)),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Column(
                children: [
                  Row(
                    children: [
                      const Text("Add Image: ",
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      if (_image != null)
                        SizedBox(
                          width: 100,
                          height: 80,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Image.file(_image!,
                                fit: BoxFit.cover, width: double.infinity),
                          ),
                        ),
                    ],
                  ),
                  Row(
                    // Row for icons
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.photo_library, size: 35),
                        onPressed: () => _pickImageFromGallery(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.photo_camera, size: 35),
                        onPressed: () => _pickImageFromCamera(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      )),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.black87)),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave(
                MarkerFormData(
                  selectedIcon: _selectedIcon,
                  label: _labelController.text,
                  description: _descriptionController.text,
                  link: _linkController.text,
                  image: _image,
                ),
              );
              Navigator.pop(context);
            }
          },
          child: const Text("Save", style: TextStyle(color: Colors.blue)),
        ),
      ],
    );
  }
}
