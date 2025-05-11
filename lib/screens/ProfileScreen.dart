import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:spherelink/core/session.dart';
import 'package:spherelink/screens/LoginScreen.dart';
import 'package:spherelink/utils/appColors.dart';
import 'package:spherelink/widget/customSnackbar.dart';
import '../core/AppConfig.dart';
import '../core/apiService.dart';

// ProfileState to manage profile image URL
class ProfileState extends ChangeNotifier {
  String? _profileImageUrl;
  String? get profileImageUrl => _profileImageUrl;

  ProfileState(String? initialImageUrl) : _profileImageUrl = initialImageUrl;

  void updateProfileImage(String? newImageUrl) {
    _profileImageUrl = newImageUrl;
    notifyListeners();
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  File? profileImage;
  String? profileImageUrl;
  bool _isEditing = false;
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    initializeDefaults();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isEditing = false;
      });

      bool success = await _apiService.updateUserProfile(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phoneNumber: _phoneController.text,
        profileImage: profileImage,
      );

      if (success) {
        await Session().savePhone(_phoneController.text);
        await Session().saveFirstName(_firstNameController.text);
        await Session().saveLastName(_lastNameController.text);
        String? newProfileImageUrl = await Session().getProfileImagePath();
        String baseUrl = AppConfig.apiBaseUrl;
        baseUrl = baseUrl.substring(0, baseUrl.lastIndexOf('/'));
        if (newProfileImageUrl != null &&
            !newProfileImageUrl.startsWith('http')) {
          newProfileImageUrl = "$baseUrl/$newProfileImageUrl";
        }
        // Update global state
        Provider.of<ProfileState>(context, listen: false)
            .updateProfileImage(newProfileImageUrl);

        showCustomSnackBar(context, Colors.green, "Profile saved successfully",
            Colors.white, "", () => {});
      } else {
        showCustomSnackBar(context, Colors.red, "Failed to save profile",
            Colors.white, "", () => {});
      }
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appprimaryBackgroundColor,
      appBar: AppBar(
        surfaceTintColor: AppColors.appprimaryBackgroundColor,
        backgroundColor: AppColors.appprimaryBackgroundColor,
        centerTitle: true,
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap:
                    _isEditing ? () => _pickImage(ImageSource.gallery) : null,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.appprimaryBackgroundColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.blue,
                          width: 3.0,
                        ),
                      ),
                      child: CircleAvatar(
                        backgroundColor: AppColors.appprimaryBackgroundColor,
                        radius: 50,
                        child: ClipOval(
                          child: profileImage != null
                              ? Image.file(
                                  profileImage!,
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                )
                              : CachedNetworkImage(
                                  imageUrl: Provider.of<ProfileState>(context)
                                          .profileImageUrl ??
                                      '',
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                  placeholder: (context, url) => const Center(
                                    child: SizedBox(
                                      width: 15,
                                      height: 15,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Image.asset(
                                    'assets/default_profile.png',
                                    fit: BoxFit.cover,
                                    width: 100,
                                    height: 100,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    if (_isEditing)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _firstNameController,
                enabled: _isEditing,
                decoration: InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: _validateName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                enabled: _isEditing,
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: _validateName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                enabled: _isEditing,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: InputDecoration(
                  counterText: '',
                  labelText: 'Phone No',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: _validatePhone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                enabled: false,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 34),
              ElevatedButton.icon(
                onPressed: _isEditing ? _saveProfile : _toggleEditMode,
                icon: Icon(
                  _isEditing ? Icons.save : Icons.edit,
                  color: Colors.white,
                ),
                label: Text(
                  _isEditing ? 'Save' : 'Edit Profile',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 0),
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final googleSignIn = GoogleSignIn();
                    bool isSignedIn = await googleSignIn.isSignedIn();

                    if (isSignedIn) {
                      // Disconnect and sign out from Google
                      try {
                        await googleSignIn.disconnect();
                      } catch (e) {
                        print("Error during Google disconnect: $e");
                      }
                      try {
                        await googleSignIn.signOut();
                      } catch (e) {
                        print("Error during Google sign out: $e");
                      }
                    }
                    await Session().clearSession();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                    );
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      showCustomSnackBar(context, AppColors.textColorPrimary,
                          "Logout successful", Colors.white, "", () => {});
                    });
                  } catch (e) {
                    showCustomSnackBar(context, Colors.red,
                        "Something went wrong", Colors.white, "", () => {});
                  }
                },
                icon: const Icon(
                  Icons.logout,
                  color: Colors.white,
                ),
                label: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 0),
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> initializeDefaults() async {
    _firstNameController.text = (await Session().getFirstName())!;
    _lastNameController.text = (await Session().getLastName())!;
    _phoneController.text = (await Session().getPhone())!;
    _emailController.text = (await Session().getEmail())!;
    profileImageUrl = await Session().getProfileImagePath();
    String baseUrl = AppConfig.apiBaseUrl;
    baseUrl = baseUrl.substring(0, baseUrl.lastIndexOf('/'));
    if (!profileImageUrl!.startsWith('http')) {
      profileImageUrl = "$baseUrl/$profileImageUrl";
    }
    // Initialize ProfileState with the initial profile image URL
    Provider.of<ProfileState>(context, listen: false)
        .updateProfileImage(profileImageUrl);
    setState(() {});
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        profileImage = File(pickedFile.path);
      });
    }
  }
}
