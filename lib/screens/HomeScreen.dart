import 'package:flutter/material.dart';
import 'package:spherelink/screens/PanoramicWithMarkers.dart';
import 'package:spherelink/utils/appColors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appprimaryBackgroundColor,
      body: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const PanoramicWithMarkers()),
          );
        },
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image(
              image: AssetImage("assets/ic_panorama.png"),
              width: 200,
              height: 200,
            ),
            Center(
              child: Text(
                "No views created yet! Tap to create one.",
                style: TextStyle(fontSize: 16),
              ),
            )
          ],
        ),
      ),
    );
  }
}
