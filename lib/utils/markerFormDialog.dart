import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:math' as math;
import 'dart:io';

import '../data/MarkerData.dart';

class MarkerFormData {
  IconData selectedIcon;
  Color selectedIconColor;
  String selectedIconStyle;
  double selectedIconRotationRadians;
  String label;
  String subTitle;
  String description;
  int nextImageId;
  String? link;
  String? linkLabel;
  File? bannerImage;
  String selectedAction;

  MarkerFormData({
    required this.selectedIcon,
    required this.selectedIconColor,
    required this.label,
    required this.subTitle,
    required this.nextImageId,
    required this.description,
    required this.selectedAction,
    required this.selectedIconStyle,
    required this.selectedIconRotationRadians,
    this.link,
    this.linkLabel,
    this.bannerImage,
  });
}

class MarkerFormDialog extends StatefulWidget {
  final Function(MarkerFormData)? onSave;
  final String? title;
  final List<String>? imageNames;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final MarkerData? initialData;

  const MarkerFormDialog(
      {super.key,
      this.title,
      this.onSave,
      this.imageNames,
      this.onCancel,
      this.onDelete,
      this.initialData});

  @override
  State<MarkerFormDialog> createState() => _MarkerFormDialogState();
}

class _MarkerFormDialogState extends State<MarkerFormDialog> {
  int _currentStep = 0;
  List<String> _steps = [];

  final List<TextEditingController> _controllers =
      List.generate(3, (_) => TextEditingController());

  static const List<(String, IconData)> actionOptions = [
    ("Label", Icons.label),
    ("Navigation", Icons.directions_walk),
    ("Banner", Icons.web_stories),
  ];
  static const List<String> iconStyleOptions = ["Straight", "Flat"];

  final _labelFormKey = GlobalKey<FormState>();
  final _descriptionFormKey = GlobalKey<FormState>();
  final _linkFormKey = GlobalKey<FormState>();
  late IconData _selectedIcon;
  late Color _selectedIconColor;
  late String? _selectedNextImageName;
  late (String, IconData) _selectedAction =
      actionOptions.first; // Initialize with a default value
  late String _selectedIconStyle =
      iconStyleOptions.first; // Initialize with a default value
  late double _selectedIconRotationRadians =
      0.0; // Initialize with a default value
  final _labelController = TextEditingController();
  final _subTitleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkController = TextEditingController();
  final _linkLabelController = TextEditingController();
  final _nextImageNameController = TextEditingController();
  File? _bannerImage;
  final ImagePicker _picker = ImagePicker();

  static const Map<String, ({IconData icon, Color color})> markerOptions = {
    "location": (icon: Icons.location_pin, color: Colors.transparent),
    "adjust": (icon: Icons.adjust, color: Colors.transparent),
    "arrowUp": (
      icon: Icons.arrow_circle_up_outlined,
      color: Colors.transparent
    ),
    "arrowdown": (
      icon: Icons.arrow_circle_down_outlined,
      color: Colors.transparent
    ),
    "assistantright": (
      icon: Icons.assistant_direction_outlined,
      color: Colors.transparent
    ),
    "flag": (icon: Icons.flag, color: Colors.transparent),
    "danger": (icon: Icons.dangerous, color: Colors.transparent),
    "block": (icon: Icons.block, color: Colors.transparent),
    "info": (icon: Icons.info, color: Colors.transparent),
    "announcement": (
      icon: Icons.announcement_outlined,
      color: Colors.transparent
    ),
    "hospital": (icon: Icons.local_hospital, color: Colors.transparent),
    "cart": (icon: Icons.shopping_cart, color: Colors.transparent),
    "shopping": (icon: Icons.shopping_bag, color: Colors.transparent),
    "restaurant": (icon: Icons.restaurant, color: Colors.transparent),
    "hotel": (icon: Icons.hotel, color: Colors.transparent),
    "parking": (icon: Icons.local_parking, color: Colors.transparent),
    "target": (icon: Icons.api_sharp, color: Colors.transparent),
    "architecture": (icon: Icons.architecture, color: Colors.transparent),
  };
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight]);
    final initialData = widget.initialData;
    _selectedIcon = initialData?.selectedIcon ?? Icons.location_pin;
    _selectedIconStyle = initialData?.selectedIconStyle ?? iconStyleOptions[0];
    _selectedIconRotationRadians =
        initialData?.selectedIconRotationRadians ?? 0;
    _selectedIconColor = initialData?.selectedIconColor ?? Colors.blueAccent;
    _selectedNextImageName = initialData?.nextImageId.toString() ?? '';
    _selectedAction = actionOptions.firstWhere(
      (action) =>
          action.$1 == (initialData?.selectedAction ?? actionOptions[0].$1),
      orElse: () => actionOptions[0],
    );

    _labelController.text = initialData?.label ?? '';
    _subTitleController.text = initialData?.subTitle ?? '';
    _descriptionController.text = initialData?.description ?? '';
    _linkController.text = initialData?.link ?? '';
    _linkLabelController.text = initialData?.linkLabel ?? '';
    _bannerImage = initialData?.bannerImage;

    _steps = getStepsForAction(_selectedAction.$1);
  }

  @override
  void dispose() {
    _labelController.dispose();
    _subTitleController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    _linkLabelController.dispose();
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
          alignLabelWithHint: true,
        ),
        validator: validator,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        maxLines: label == "Description" ? 5 : 1,
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

  List<String> getStepsForAction(String action) {
    if (action == "Banner") {
      return ["Preferences", "Label", "Description", "Photos"];
    }
    return ["Preferences", "Description"];
  }

  void _updateSteps() {
    setState(() {
      if (_selectedAction.$1 == "Banner") {
        _steps = [
          "Preferences",
          "Label",
          "Description",
          "Photos",
        ];
      } else {
        _steps = ["Preferences", "Description"];
      }
      _currentStep = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
        child: AlertDialog(
      titlePadding: const EdgeInsets.symmetric(vertical: 16),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Column(
        children: [
          Row(
            children: [
              // Left button (fixed width placeholder when hidden)
              Visibility(
                visible: _currentStep > 0,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _currentStep--;
                    });
                  },
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    size: 32,
                  ),
                ),
              ),

              // Title remains centered
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    "${widget.title} Marker",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Right button (fixed width placeholder when hidden)
              Visibility(
                  visible: _currentStep < _steps.length - 1,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: IconButton(
                    onPressed: () {
                      switch (_currentStep) {
                        case 0:
                          setState(() {
                            _currentStep++;
                          });
                          break;
                        case 1:
                          if (_labelFormKey.currentState!.validate()) {
                            setState(() {
                              _currentStep++;
                            });
                          }
                          break;
                        case 2:
                          if (_descriptionFormKey.currentState!.validate()) {
                            setState(() {
                              _currentStep++;
                            });
                          }
                          break;
                      }
                    },
                    icon: const Icon(
                      Icons.chevron_right_rounded,
                      size: 32,
                    ),
                  ))
            ],
          ),
          const Divider(thickness: 4)
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 410,
          maxWidth: 450,
        ),
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 30,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _steps.length,
                      (index) => GestureDetector(
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: _currentStep == index ? 26 : 18,
                                  height: _currentStep == index ? 26 : 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _currentStep == index
                                        ? Colors.green
                                        : Colors.blue,
                                  ),
                                ),
                                Text(
                                  "${index + 1}",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: _currentStep == index ? 14 : 12,
                                  ),
                                ),
                              ],
                            ),
                            if (index < _steps.length - 1)
                              Container(
                                width: 3,
                                height:
                                    _selectedAction.$1 == "Banner" ? 30 : 130,
                                color: Colors.grey,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildStepContent(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: GestureDetector(
                onTap:
                    widget.title == "Edit" ? widget.onDelete : widget.onCancel,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18.0, vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.title == "Edit" ? "Delete" : "Cancel",
                      style: TextStyle(
                        color:
                            widget.title == "Edit" ? Colors.red : Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.title == "Edit")
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 18.0, vertical: 12),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (_currentStep == _steps.length - 1)
                    GestureDetector(
                      onTap: () {
                        if (_selectedAction.$1 == "Banner") {
                          if (!_linkFormKey.currentState!.validate()) {
                            return;
                          }
                        } else {
                          if (!_labelFormKey.currentState!.validate()) {
                            return;
                          }
                        }
                        widget.onSave!(MarkerFormData(
                          selectedAction: _selectedAction.$1,
                          selectedIcon: _selectedIcon,
                          selectedIconStyle: _selectedIconStyle,
                          selectedIconRotationRadians:
                              _selectedIconRotationRadians,
                          selectedIconColor: _selectedIconColor,
                          label: _labelController.text,
                          subTitle: _subTitleController.text,
                          description: _descriptionController.text,
                          nextImageId: _selectedNextImageName != null
                              ? widget.imageNames!
                                  .indexOf(_selectedNextImageName!)
                              : -1,
                          link: _linkController.text.isNotEmpty
                              ? _linkController.text
                              : null,
                          linkLabel: _linkLabelController.text.isNotEmpty
                              ? _linkLabelController.text
                              : null,
                          bannerImage: _bannerImage,
                        ));
                        Navigator.of(context).pop();
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 18.0, vertical: 12),
                        child: Text(
                          "Save",
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    ));
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return Form(
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center, // Centers the content vertically
            crossAxisAlignment:
                CrossAxisAlignment.stretch, // Ensures full width
            children: [
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
                    width: 170,
                    child: DropdownButtonFormField<(String, IconData)>(
                      value: _selectedAction,
                      decoration: const InputDecoration(),
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
                          if (widget.initialData == null) {
                            // Only clear for new entries
                            _labelController.clear();
                            _subTitleController.clear();
                            _descriptionController.clear();
                            _linkController.clear();
                            _bannerImage = null;
                          }
                        });
                        _updateSteps(); // Update tabs dynamically
                      },
                    ),
                  ),
                ],
              ),
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
                                actionsPadding: const EdgeInsets.all(8),
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
              Row(
                children: [
                  const Expanded(
                    flex: 3,
                    child: Text(
                      "Icon Style:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: iconStyleOptions.map((item) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Radio<String>(
                              value: item,
                              groupValue: _selectedIconStyle,
                              activeColor: Colors.teal,
                              onChanged: (newValue) {
                                setState(() {
                                  _selectedIconStyle = newValue!;
                                });
                              },
                            ),
                            Text(item, style: const TextStyle(fontSize: 14)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                      flex: 3,
                      child: Text(
                        "Rotation:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      )),
                  const Spacer(),
                  SizedBox(
                    width: 170,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2.0,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 0,
                        ),
                      ),
                      child: Slider(
                        value: _selectedIconRotationRadians,
                        min: 0,
                        max: 2 * math.pi,
                        divisions: 360,
                        label:
                            "${(_selectedIconRotationRadians * 180 / math.pi).toInt()}",
                        onChanged: (double newValue) {
                          setState(() {
                            _selectedIconRotationRadians = newValue;
                          });
                        },
                        activeColor: Colors.teal,
                        inactiveColor: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case 1:
        return Form(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          key: _labelFormKey,
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center, // Centers the content vertically
            crossAxisAlignment:
                CrossAxisAlignment.stretch, // Ensures full width
            children: [
              if (_selectedAction.$1 == "Label" ||
                  _selectedAction.$1 == "Banner")
                _buildTextField(
                  label: _selectedAction.$1 == "Label" ? "Label" : "Title",
                  maxLength: 50,
                  controller: _labelController,
                  validator: (value) => value?.isEmpty ?? true
                      ? _selectedAction.$1 == "Label"
                          ? "Label is required"
                          : "Title is required"
                      : null,
                ),
              if (_selectedAction.$1 == "Navigation")
                DropdownButtonFormField<String>(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: const InputDecoration(
                    labelText: "Next Image",
                    border: OutlineInputBorder(),
                  ),
                  value: widget.imageNames!.contains(_selectedNextImageName)
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
                      return "Next image is required";
                    }
                    return null;
                  },
                  items: widget.imageNames?.map((item) {
                    return DropdownMenuItem(
                      value: item,
                      child: Text(item),
                    );
                  }).toList(),
                ),
              if (_selectedAction.$1 == "Banner")
                _buildTextField(
                  label: "Subtitle",
                  maxLength: 50,
                  controller: _subTitleController,
                  validator: (value) =>
                      value?.isEmpty ?? true ? "Subtitle is required" : null,
                ),
            ],
          ),
        );
      case 2:
        return Form(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          key: _descriptionFormKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_selectedAction.$1 == "Banner")
                _buildTextField(
                  label: "Description",
                  controller: _descriptionController,
                  maxLength: 150,
                  validator: (value) =>
                      value?.isEmpty ?? true ? "Description is required" : null,
                ),
            ],
          ),
        );
      case 3:
        return Form(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          key: _linkFormKey,
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center, // Centers the content vertically
            crossAxisAlignment:
                CrossAxisAlignment.stretch, // Ensures full width
            children: [
              if (_selectedAction.$1 == "Banner")
                Column(
                  children: [
                    _buildTextField(
                      label: "Link",
                      controller: _linkController,
                      validator: (value) {
                        final urlRegex = RegExp(
                            r'^(http(s)?:\/\/)?(www\.)?[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,}(\/\S*)?$');
                        if (_linkLabelController.text.isNotEmpty) {
                          if (!urlRegex.hasMatch(value!)) {
                            return 'Enter a valid link.';
                          }
                        }
                        return null;
                      },
                    ),
                    _buildTextField(
                      label: "Link label",
                      controller: _linkLabelController,
                      validator: (value) {
                        if (_linkController.text.isNotEmpty && value!.isEmpty) {
                          return "Link label is required.";
                        }
                        return null;
                      },
                    ),
                    _buildImagePicker(),
                  ],
                )
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
