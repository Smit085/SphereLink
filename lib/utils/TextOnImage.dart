import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:widget_to_marker/widget_to_marker.dart';

class TextOnImage extends StatelessWidget {
  const TextOnImage({
    super.key,
    required this.text,
  });
  final String text;
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Image(
          image: AssetImage(
            "assets/marker.png",
          ),
          height: 150,
          width: 150,
        ),
        Text(
          text,
          style: TextStyle(color: Colors.black),
        )
      ],
    );
  }
}