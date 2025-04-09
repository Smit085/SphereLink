import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spherelink/core/session.dart';
import 'package:spherelink/screens/LoginScreen.dart';
import 'package:spherelink/utils/appColors.dart';
import 'package:spherelink/widget/customSnackbar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Controllers for text fields
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  File? profileImage;

  bool _isEditing = false;

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

  void _saveProfile() {
    setState(() {
      _isEditing = false;
      Session().savePhone(_phoneController.text);
      Session().saveSession(
          "${_firstNameController.text} ${_lastNameController.text}");
    });
    showCustomSnackBar(context, Colors.green, "Profile saved successfully",
        Colors.white, "", () => {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appprimaryBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.appprimaryBackgroundColor,
        centerTitle: true, // Center the title
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile Picture
            GestureDetector(
              onTap: _isEditing
                  ? () {
                      _pickImage(ImageSource.gallery);
                    }
                  : null,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.blue, // Add border to profile
                        width: 3.0,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: profileImage != null
                          ? FileImage(profileImage!)
                          : const AssetImage('assets/profile_1.jpeg')
                              as ImageProvider,
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

            // First Name
            TextField(
              controller: _firstNameController,
              enabled: _isEditing,
              decoration: InputDecoration(
                labelText: 'First Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Last Name
            TextField(
              controller: _lastNameController,
              enabled: _isEditing,
              decoration: InputDecoration(
                labelText: 'Last Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Phone
            TextField(
              controller: _phoneController,
              enabled: _isEditing,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Email
            TextField(
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
            const SizedBox(height: 54),

            // Edit/Save Button

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

            // Logout Button
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await Session().clearSession();
                  await GoogleSignIn().disconnect();
                  await GoogleSignIn().signOut();
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
    );
  }

  Future<void> initializeDefaults() async {
    String username = (await Session().getSession())!;
    _firstNameController.text = username.split(" ")[0];
    _lastNameController.text = username.split(" ")[1];
    _phoneController.text = (await Session().getPhone())!;
    _emailController.text = (await Session().getEmail())!;
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
