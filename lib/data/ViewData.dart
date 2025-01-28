import 'dart:io';

import '../screens/PanoramicWithMarkers.dart';
import 'PanoramaImage.dart';

class ViewData {
  final List<PanoramaImage> panoramaImages;
  final String viewName;
  final File thumbnailImage;
  final DateTime dateTime;

  ViewData({
    required this.panoramaImages,
    required this.viewName,
    required this.thumbnailImage,
    required this.dateTime,
  });

  Map<String, dynamic> toJson() {
    return {
      "panoramaImages": panoramaImages.map((e) => e.toJson()).toList(),
      "viewName": viewName,
      "thumbnailImage": thumbnailImage.path,
      "dateTime": dateTime.toIso8601String(),
    };
  }

  static ViewData fromJson(Map<String, dynamic> json) {
    return ViewData(
      panoramaImages: (json["panoramaImages"] as List)
          .map((e) => PanoramaImage.fromJson(e as Map<String, dynamic>))
          .toList(),
      viewName: json["viewName"],
      thumbnailImage: File(json["thumbnailImage"]),
      dateTime: DateTime.parse(json["dateTime"]),
    );
  }
}
