import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomizeBottomSheet extends StatefulWidget {
  const CustomizeBottomSheet({super.key});

  @override
  _CustomizeBottomSheetState createState() => _CustomizeBottomSheetState();
}

class _CustomizeBottomSheetState extends State<CustomizeBottomSheet> {
  bool isOpen = false;

  void toggleSheet() {
    setState(() {
      isOpen = !isOpen;
    });
  }

  @override
  void initState() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight]);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Animated Bottom Sheet
        AnimatedPositioned(
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          bottom: isOpen ? 0 : -280,
          left: 0,
          right: 0,
          child: Container(
            width: double.infinity,
            height: 280,
            decoration: BoxDecoration(
              color: Colors.red.shade900.withOpacity(0.85),
            ),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 30), // Space for overlapping button
                Text(
                  "Modern Bottom Sheet",
                  style: GoogleFonts.lato(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 15),
              ],
            ),
          ),
        ),

        // Overlapping Button
        AnimatedPositioned(
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          bottom: isOpen ? 280 - 25 : 10, // Adjusts dynamically
          child: GestureDetector(
            onTap: toggleSheet,
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(45),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 5,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Center(
                child: Icon(
                  isOpen ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                  color: Colors.red.shade900,
                  size: 30,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
