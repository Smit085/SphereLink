import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:spherelink/utils/appColors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.appprimaryBackgroundColor,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
              child: Text(
            "Profile Screen",
            style: TextStyle(fontSize: 24),
          ))
        ],
      ),
    );
  }
}
