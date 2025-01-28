import 'dart:io';

import 'MarkerData.dart';

class PanoramaImage {
  final File image;
  String imageName;
  final List<MarkerData> markers;

  PanoramaImage(this.image, this.imageName) : markers = [];

  // Convert PanoramaImage to JSON
  Map<String, dynamic> toJson() {
    return {
      "image": image.path, // Save the file path
      "imageName": imageName,
      "markers": markers.map((marker) => marker.toJson()).toList(),
    };
  }

  // Create PanoramaImage from JSON
  static PanoramaImage fromJson(Map<String, dynamic> json) {
    final panoramaImage = PanoramaImage(
      File(json["image"]),
      json["imageName"],
    );

    panoramaImage.markers.addAll(
      (json["markers"] as List)
          .map((marker) => MarkerData.fromJson(marker))
          .toList(),
    );

    return panoramaImage;
  }
}
