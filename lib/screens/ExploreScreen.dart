import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:spherelink/utils/appColors.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.appprimaryBackgroundColor,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
              child: Text(
            "Explore Screen",
            style: TextStyle(fontSize: 24),
          ))
        ],
      ),
    );
  }
}
