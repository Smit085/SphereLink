// ViewData.dart
import 'dart:io';
import 'package:mappls_gl/mappls_gl.dart';
import 'PanoramaImage.dart';

class ViewData {
  List<PanoramaImage> panoramaImages;
  String viewName;
  File? thumbnailImage;
  String? thumbnailImageUrl;
  DateTime dateTime;
  LatLng? location;
  String? description;
  bool isPublished;

  ViewData({
    this.location,
    this.description,
    this.thumbnailImageUrl,
    this.thumbnailImage,
    this.isPublished = false,
    required this.panoramaImages,
    required this.viewName,
    required this.dateTime,
  });

  Map<String, dynamic> toJson() {
    return {
      "panoramaImages": panoramaImages.map((e) => e.toJson()).toList(),
      "viewName": viewName,
      "thumbnailImage": thumbnailImage?.path,
      "thumbnailImageUrl": thumbnailImageUrl,
      "dateTime": dateTime.toIso8601String(),
      "location": location != null
          ? {"latitude": location!.latitude, "longitude": location!.longitude}
          : null,
      "description": description?.toString(),
      'isPublished': isPublished,
    };
  }

  static ViewData fromJson(Map<String, dynamic> json) {
    return ViewData(
      panoramaImages: (json["panoramaImages"] as List)
          .map((e) => PanoramaImage.fromJson(e as Map<String, dynamic>))
          .toList(),
      viewName: json["viewName"] as String? ?? "Untitled",
      thumbnailImage: json["thumbnailImage"] != null
          ? File(json["thumbnailImage"])
          : null, // Only for local storage
      thumbnailImageUrl: json["thumbnailImagePath"] as String?, // From server
      dateTime: DateTime.parse(
          json["dateTime"] as String? ?? DateTime.now().toIso8601String()),
      location: json["location"] != null
          ? LatLng(
              (json["location"] as List<dynamic>)[0] as double,
              (json["location"] as List<dynamic>)[1] as double,
            )
          : null,
      description: json["description"] as String?,
      isPublished: json['isPublished'] as bool? ?? false,
    );
  }
}
