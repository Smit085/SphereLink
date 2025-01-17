import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

Future<File?> _mergeImagesInBackground(List<Object> input) async {
  final frontBytes = input[0] as Uint8List;
  final backBytes = input[1] as Uint8List;
  final outputPath = input[2] as String;

  final front = img.decodeImage(frontBytes);
  final back = img.decodeImage(backBytes);

  if (front == null || back == null) {
    return null; // Return null if decoding fails
  }

  final combinedWidth = front.width + back.width;
  final combinedHeight = max(front.height, back.height);
  final mergedImage = img.Image(width: combinedWidth, height: combinedHeight);

  img.fill(mergedImage, color: img.ColorRgb8(0, 0, 0));

  for (var y = 0; y < front.height; y++) {
    for (var x = 0; x < front.width; x++) {
      mergedImage.setPixel(x, y, front.getPixel(x, y));
    }
  }

  for (var y = 0; y < back.height; y++) {
    for (var x = 0; x < back.width; x++) {
      mergedImage.setPixel(x + front.width, y, back.getPixel(x, y));
    }
  }

  final mergedFile = File(outputPath);
  await mergedFile.writeAsBytes(img.encodeJpg(mergedImage));
  return mergedFile;
}

Future<File?> mergeImages(
    List<XFile> pickedImages, BuildContext context) async {
  try {
    final frontBytes = await pickedImages[0].readAsBytes();
    final backBytes = await pickedImages[1].readAsBytes();

    final directory = await getApplicationDocumentsDirectory();
    final mergedPath = '${directory.path}/merged_panorama.jpg';

    final mergedFile = await compute(
      _mergeImagesInBackground,
      [frontBytes, backBytes, mergedPath],
    );

    if (mergedFile != null) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Merged image saved at $mergedPath')),
      // );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            duration: Duration(milliseconds: 800),
            content: Text('Failed to merge images.')),
      );
    }
    return mergedFile;
  } catch (e) {
    print('Error merging images: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          duration: const Duration(milliseconds: 800),
          content: Text('Error merging images: $e')),
    );
    return null;
  }
}
