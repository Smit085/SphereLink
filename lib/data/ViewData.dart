import 'dart:io';
import 'package:mappls_gl/mappls_gl.dart';
import 'PanoramaImage.dart';

class ViewData {
  final String? viewId;
  String viewName;
  List<PanoramaImage> panoramaImages;
  File? thumbnailImage;
  String? thumbnailImageUrl;
  DateTime dateTime;
  double? latitude;
  double? longitude;
  String? description;
  bool isPublished;
  String? creatorName;
  String? creatorProfileImagePath;
  String? cityName;
  double? averageRating;
  bool isPublic;

  ViewData({
    this.viewId,
    this.latitude,
    this.longitude,
    this.description,
    this.thumbnailImageUrl,
    this.thumbnailImage,
    this.isPublished = false,
    required this.panoramaImages,
    required this.viewName,
    required this.dateTime,
    this.creatorName,
    this.creatorProfileImagePath,
    this.cityName,
    this.averageRating,
    this.isPublic = true,
  });

  Map<String, dynamic> toJson() {
    return {
      "panoramaImages": panoramaImages.map((e) => e.toJson()).toList(),
      "viewName": viewName,
      "thumbnailImage": thumbnailImage?.path,
      "thumbnailImageUrl": thumbnailImageUrl,
      "dateTime": dateTime.toIso8601String(),
      "latitude": latitude,
      "longitude": longitude,
      "description": description?.toString(),
      'isPublished': isPublished,
    };
  }

  static ViewData fromJson(Map<String, dynamic> json) {
    return ViewData(
      viewId: json['viewId']?.toString(),
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
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      description: json["description"] as String?,
      isPublished: json['isPublished'] as bool? ?? false,
      creatorName: json['creatorName'] as String?,
      creatorProfileImagePath: json['creatorProfileImagePath'] as String?,
      cityName: json['cityName'] as String?,
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      isPublic: json['isPublic'] as bool? ?? true,
    );
  }
}
