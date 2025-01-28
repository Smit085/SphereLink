import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../data/MarkerData.dart';

class MarkerFormData {
  IconData selectedIcon;
  Color selectedIconColor;
  String label;
  String description;
  int nextImageId;
  String? link;
  File? bannerImage;
  String selectedAction;

  MarkerFormData({
    required this.selectedIcon,
    required this.selectedIconColor,
    required this.label,
    required this.nextImageId,
    required this.description,
    required this.selectedAction,
    this.link,
    this.bannerImage,
  });
}

class MarkerFormDialog extends StatefulWidget {
  final Function(MarkerFormData) onSave;
  final VoidCallback onCancel;
  final List<String> imageNames;
  final MarkerData? initialData;
  final String title;

  const MarkerFormDialog(
      {super.key,
      required this.title,
      required this.onSave,
      required this.onCancel,
      required this.imageNames,
      this.initialData});

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
  late IconData _selectedIcon;
  late Color _selectedIconColor;
  late String? _selectedNextImageName;
  late (String, IconData) _selectedAction;
  final _labelController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkController = TextEditingController();
  final _nextImageNameController = TextEditingController();
  File? _bannerImage;
  final ImagePicker _picker = ImagePicker();

  static const Map<String, ({IconData icon, Color color})> markerOptions = {
    "location": (icon: Icons.location_on, color: Colors.red),
    "adjust": (icon: Icons.adjust, color: Colors.white),
    "arrowUp": (icon: Icons.arrow_circle_up_outlined, color: Colors.white10),
    "arrowdown": (
      icon: Icons.arrow_circle_down_outlined,
      color: Colors.white10
    ),
    "assistantright": (
      icon: Icons.assistant_direction_outlined,
      color: Colors.white10
    ),
    "flag": (icon: Icons.flag, color: Colors.white10),
    "danger": (icon: Icons.dangerous, color: Colors.blue),
    "block": (icon: Icons.block, color: Colors.red),
    "info": (icon: Icons.info, color: Colors.blue),
    "announcement": (icon: Icons.announcement_outlined, color: Colors.blue),
    "cart": (icon: Icons.shopping_cart, color: Colors.orange),
    "shopping": (icon: Icons.shopping_bag, color: Colors.orange),
    "restaurant": (icon: Icons.restaurant, color: Colors.red),
    "hotel": (icon: Icons.hotel, color: Colors.purple),
    "parking": (icon: Icons.local_parking, color: Colors.blue),
    "target": (icon: Icons.api_sharp, color: Colors.red),
    "architecture": (icon: Icons.architecture, color: Colors.red),
  };

  @override
  void initState() {
    super.initState();
    final initialData = widget.initialData;
    _selectedIcon = initialData?.selectedIcon ?? Icons.location_on;
    _selectedIconColor = initialData?.selectedIconColor ?? Colors.red;
    _selectedNextImageName = initialData?.nextImageId.toString() ?? '';
    _selectedAction = actionOptions.firstWhere(
      (action) =>
          action.$1 == (initialData?.selectedAction ?? actionOptions[0].$1),
      orElse: () => actionOptions[0],
    );

    _labelController.text = initialData?.label ?? '';
    _descriptionController.text = initialData?.description ?? '';
    _linkController.text = initialData?.link ?? '';
    _bannerImage = initialData?.bannerImage;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    _nextImageNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      setState(() {
        _bannerImage = pickedFile != null ? File(pickedFile.path) : null;
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
        enableSuggestions: true,
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
            if (_bannerImage != null)
              SizedBox(
                width: 80,
                height: 60,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(_bannerImage!, fit: BoxFit.cover),
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
          maxLength: 50,
          controller: _labelController,
          validator: (value) =>
              value?.isEmpty ?? true ? "Label is required" : null,
        );
      case "Navigation":
        return DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: "Next Image",
            border: OutlineInputBorder(),
          ),
          value: widget.imageNames.contains(_selectedNextImageName)
              ? _selectedNextImageName
              : null,
          onChanged: (newValue) {
            setState(() {
              _selectedNextImageName = newValue!;
              _nextImageNameController.text = newValue.toString() ?? '';
            });
          },
          validator: (value) {
            if (value == null) {
              return "Next Image No. is required";
            }
            return null;
          },
          items: widget.imageNames.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
        );
      case "Banner":
        return Column(
          children: [
            _buildTextField(
              label: "Label",
              maxLength: 50,
              controller: _labelController,
              validator: (value) =>
                  value?.isEmpty ?? true ? "Label is required" : null,
            ),
            _buildTextField(
              label: "Description",
              controller: _descriptionController,
              maxLength: 150,
              validator: (value) =>
                  value?.isEmpty ?? true ? "Description is required" : null,
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
    return SingleChildScrollView(
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Center(
          child: Text(
            "${widget.title} Marker",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        content: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 300,
              maxWidth: 400,
            ),
            child: SingleChildScrollView(
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
                                  contentPadding:
                                      EdgeInsets.symmetric(horizontal: 8)),
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
                                setState(() {
                                  _selectedAction = newValue!;
                                  _labelController.clear();
                                  _descriptionController.clear();
                                  _linkController.clear();
                                  _bannerImage = null;
                                });
                              }),
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
                        IconButton(
                            onPressed: () {
                              showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('Pick a color!'),
                                      content: SingleChildScrollView(
                                        child: ColorPicker(
                                          pickerColor:
                                              _selectedIconColor, //default color
                                          onColorChanged: (Color color) {
                                            setState(() {
                                              _selectedIconColor = color;
                                            });
                                          },
                                        ),
                                      ),
                                      actions: <Widget>[
                                        ElevatedButton(
                                          child: const Text('DONE'),
                                          onPressed: () {
                                            Navigator.of(context)
                                                .pop(); //dismiss the color picker
                                          },
                                        ),
                                      ],
                                    );
                                  });
                            },
                            icon: Icon(
                              Icons.color_lens,
                              color: _selectedIconColor,
                            )),
                        SizedBox(
                            width: 70,
                            child: DropdownButtonFormField<IconData>(
                              value: _selectedIcon,
                              decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.zero),
                              items: markerOptions.entries.map((marker) {
                                final icon = marker.value.icon;
                                return DropdownMenuItem(
                                  value: icon,
                                  child: Icon(icon, color: _selectedIconColor),
                                );
                              }).toList(),
                              onChanged: (newIcon) {
                                if (newIcon != null) {
                                  setState(() {
                                    _selectedIcon = newIcon;
                                  });
                                }
                              },
                            )),
                      ],
                    ),
                    _buildDynamicInputs(),
                  ],
                ),
              ),
            )),
        actions: [
          TextButton(
            onPressed: widget.onCancel,
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                widget.onSave(MarkerFormData(
                  selectedAction: _selectedAction.$1,
                  selectedIcon: _selectedIcon,
                  selectedIconColor: _selectedIconColor,
                  label: _labelController.text,
                  description: _descriptionController.text,
                  nextImageId:
                      widget.imageNames.indexOf(_selectedNextImageName!),
                  link: _linkController.text.isNotEmpty
                      ? _linkController.text
                      : null,
                  bannerImage: _bannerImage,
                ));
                Navigator.of(context).pop();
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
