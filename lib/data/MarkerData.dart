import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MarkerData {
  double longitude;
  double latitude;
  String label;
  String description;
  String selectedIconStyle;
  IconData selectedIcon;
  Color selectedIconColor;
  int nextImageId;
  double selectedIconRotationRadians;
  String selectedAction;
  File? bannerImage;
  String? link;

  MarkerData(
      {required this.description,
      required this.selectedAction,
      required this.longitude,
      required this.latitude,
      required this.nextImageId,
      required this.selectedIconColor,
      required this.selectedIconStyle,
      required this.selectedIconRotationRadians,
      this.label = "",
      this.selectedIcon = Icons.location_pin,
      this.bannerImage,
      this.link});

  // Convert MarkerData to JSON
  Map<String, dynamic> toJson() {
    return {
      "longitude": longitude,
      "latitude": latitude,
      "label": label,
      "description": description,
      "selectedIcon": selectedIcon.codePoint,
      "selectedIconStyle": selectedIconStyle,
      "selectedIconRotationRadians": selectedIconRotationRadians,
      "selectedIconColor": selectedIconColor.value,
      "nextImageId": nextImageId,
      "selectedAction": selectedAction,
      "bannerImage": bannerImage?.path,
      "link": link,
    };
  }

  // Create MarkerData from JSON
  static MarkerData fromJson(Map<String, dynamic> json) {
    return MarkerData(
      longitude: json["longitude"],
      latitude: json["latitude"],
      label: json["label"],
      description: json["description"],
      selectedIconStyle: json["selectedIconStyle"],
      selectedIconRotationRadians: json["selectedIconRotationRadians"],
      selectedIcon: IconData(json["selectedIcon"], fontFamily: 'MaterialIcons'),
      selectedIconColor: Color(json["selectedIconColor"]),
      nextImageId: json["nextImageId"],
      selectedAction: json["selectedAction"],
      bannerImage:
          json["bannerImage"] != null ? File(json["bannerImage"]) : null,
      link: json["link"],
    );
  }
}
