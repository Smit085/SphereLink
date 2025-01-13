import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class MarkerFormData {
  IconData selectedIcon;
  String label;
  String description;
  int nextImageId;
  String? link;
  File? image;

  MarkerFormData({
    required this.selectedIcon,
    required this.label,
    required this.nextImageId,
    required this.description,
    this.link,
    this.image,
  });
}

class MarkerFormDialog extends StatefulWidget {
  final Function(MarkerFormData) onSave;
  final VoidCallback onCancel;
  final int maxImageId;

  const MarkerFormDialog(
    int length, {
    super.key,
    required this.onSave,
    required this.onCancel,
  }) : maxImageId = length;

  @override
  State<MarkerFormDialog> createState() => _MarkerFormDialogState();
}

class _MarkerFormDialogState extends State<MarkerFormDialog> {
  static const List<(String, IconData)> actionOptions = [
    ("Label", Icons.label),
    ("Navigation", Icons.directions_walk),
    ("Banner", Icons.web_stories),
  ];

  final _formKey = GlobalKey<FormState>();
  IconData _selectedIcon = Icons.location_on;
  (String, IconData) _selectedAction = actionOptions[0];
  final _labelController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkController = TextEditingController();
  final _nextImageIdController = TextEditingController(); // For Navigation
  File? _image;
  final ImagePicker _picker = ImagePicker();

  static const Map<String, ({IconData icon, Color color})> markerOptions = {
    "location": (icon: Icons.location_on, color: Colors.red),
    "arrowUp": (icon: Icons.arrow_circle_up_outlined, color: Colors.white10),
    "info": (icon: Icons.info, color: Colors.blue),
    "cart": (icon: Icons.shopping_cart, color: Colors.orange),
    "restaurant": (icon: Icons.restaurant, color: Colors.red),
    "hotel": (icon: Icons.hotel, color: Colors.purple),
    "parking": (icon: Icons.local_parking, color: Colors.blue),
  };

  @override
  void dispose() {
    _labelController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    _nextImageIdController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      setState(() {
        _image = pickedFile != null ? File(pickedFile.path) : null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: validator,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Add Image:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_image != null)
              SizedBox(
                width: 80,
                height: 60,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(_image!, fit: BoxFit.cover),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.photo_library, size: 28),
              onPressed: () => _pickImage(ImageSource.gallery),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.camera_alt, size: 28),
              onPressed: () => _pickImage(ImageSource.camera),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDynamicInputs() {
    switch (_selectedAction.$1) {
      case "Label":
        return _buildTextField(
          label: "Give Label",
          controller: _labelController,
          validator: (value) =>
              value?.isEmpty ?? true ? "Label is required" : null,
        );
      case "Navigation":
        return _buildTextField(
          label: "Next Image No.",
          controller: _nextImageIdController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "Next Image No. is required";
            }
            final nextImageId = int.tryParse(value);
            if (nextImageId == null ||
                nextImageId <= 0 ||
                nextImageId > widget.maxImageId) {
              return "Please enter a valid ID between 1 and ${widget.maxImageId}";
            }
            return null;
          },
        );
      case "Banner":
        return Column(
          children: [
            _buildTextField(
              label: "Label",
              controller: _labelController,
              validator: (value) =>
                  value?.isEmpty ?? true ? "Label is required" : null,
            ),
            _buildTextField(
              label: "Description",
              controller: _descriptionController,
              maxLength: 50,
              validator: (value) => value != null && value.length > 50
                  ? "Max 50 characters allowed"
                  : null,
            ),
            _buildTextField(
              label: "Link",
              controller: _linkController,
            ),
            _buildImagePicker(),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: const Center(
        child: Text(
          "Add Marker",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              Row(
                children: [
                  const Expanded(
                      flex: 3,
                      child: Text(
                        "Reference Action:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      )),
                  const Spacer(),
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<(String, IconData)>(
                      value: _selectedAction,
                      decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                      items: actionOptions.map((item) {
                        return DropdownMenuItem(
                          value: item,
                          child: Row(
                            children: [
                              Text(item.$1),
                              const SizedBox(width: 8),
                              Icon(item.$2, size: 18),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() => _selectedAction = newValue!);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    "Select Icon:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  SizedBox(
                      width: 70,
                      child: DropdownButtonFormField<IconData>(
                        value: _selectedIcon,
                        decoration: const InputDecoration(
                            contentPadding: EdgeInsets.zero),
                        items: markerOptions.entries.map((marker) {
                          final icon = marker.value.icon;
                          final color = marker.value
                              .color; // Assuming markerOption has a 'color' property
                          return DropdownMenuItem(
                            value: icon,
                            child: Icon(icon,
                                color:
                                    color), // Use the color from markerOption
                          );
                        }).toList(),
                        onChanged: (newIcon) => setState(() {
                          _selectedIcon = newIcon!;
                        }),
                      ))
                ],
              ),
              const SizedBox(height: 12),
              _buildDynamicInputs(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave(MarkerFormData(
                selectedIcon: _selectedIcon,
                label: _labelController.text,
                description: _descriptionController.text,
                nextImageId: int.tryParse(_nextImageIdController.text) ?? 0,
                link: _linkController.text.isNotEmpty
                    ? _linkController.text
                    : null,
                image: _image,
              ));
              Navigator.of(context).pop();
            }
          },
          child: const Text("Save"),
        ),
      ],
    );
  }
}
