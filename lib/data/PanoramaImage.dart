// PanoramaImage.dart
import 'dart:io';
import 'MarkerData.dart';

class PanoramaImage {
  File? image; // Local storage (remains File, null from server)
  String? imageUrl; // Online storage (URL from server)
  String imageName;
  final List<MarkerData> markers;

  PanoramaImage(this.image, this.imageUrl, this.imageName) : markers = [];

  Map<String, dynamic> toJson() {
    return {
      'image': image?.path, // Store file path locally
      'imageUrl': imageUrl, // Store URL if online
      "imageName": imageName,
      "markers": markers.map((marker) => marker.toJson()).toList(),
    };
  }

  static PanoramaImage fromJson(Map<String, dynamic> json) {
    final panoramaImage = PanoramaImage(
      json['image'] != null
          ? File(json['image'])
          : null, // Only for local storage
      json['imagePath'] as String?, // URL from server
      json["imageName"] as String? ?? "Unknown",
    );

    panoramaImage.markers.addAll(
      (json["markers"] as List? ?? [])
          .map((marker) => MarkerData.fromJson(marker))
          .toList(),
    );

    return panoramaImage;
  }
}
