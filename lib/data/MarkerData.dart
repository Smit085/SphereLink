import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MarkerData {
  double longitude;
  double latitude;
  String label;
  String subTitle;
  String description;
  String address;
  String? phoneNumber;
  String selectedIconStyle;
  IconData selectedIcon;
  Color selectedIconColor;
  int nextImageId;
  double selectedIconRotationRadians;
  String selectedAction;
  List<File?>? bannerImage;
  String? link;

  String? linkLabel;

  MarkerData(
      {required this.description,
      required this.address,
      required this.selectedAction,
      required this.longitude,
      required this.latitude,
      required this.nextImageId,
      required this.selectedIconColor,
      required this.selectedIconStyle,
      required this.selectedIconRotationRadians,
      this.label = "",
      this.subTitle = "",
      this.selectedIcon = Icons.location_pin,
      this.bannerImage,
      this.link,
      this.phoneNumber,
      this.linkLabel});

  // Convert MarkerData to JSON
  Map<String, dynamic> toJson() {
    return {
      "longitude": longitude,
      "latitude": latitude,
      "label": label,
      "subTitle": subTitle,
      "description": description,
      "address": address,
      "phoneNumber": phoneNumber,
      "selectedIcon": selectedIcon.codePoint,
      "selectedIconStyle": selectedIconStyle,
      "selectedIconRotationRadians": selectedIconRotationRadians,
      "selectedIconColor": selectedIconColor.value,
      "nextImageId": nextImageId,
      "selectedAction": selectedAction,
      "bannerImages":
          bannerImage?.map((file) => file?.path).toList(), // Serialize paths
      "link": link,
      "LinkLabel": linkLabel,
    };
  }

  // Create MarkerData from JSON
  static MarkerData fromJson(Map<String, dynamic> json) {
    return MarkerData(
      longitude: json["longitude"],
      latitude: json["latitude"],
      label: json["label"],
      linkLabel: json["linkLabel"],
      subTitle: json["subTitle"],
      description: json["description"],
      address: json["address"],
      phoneNumber: json["phoneNumber"],
      selectedIconStyle: json["selectedIconStyle"],
      selectedIconRotationRadians: json["selectedIconRotationRadians"],
      selectedIcon: IconData(json["selectedIcon"], fontFamily: 'MaterialIcons'),
      selectedIconColor: Color(json["selectedIconColor"]),
      nextImageId: json["nextImageId"],
      selectedAction: json["selectedAction"],
      bannerImage:
          (json["bannerImages"] as List?)?.map((path) => File(path)).toList() ??
              [],
      link: json["link"],
    );
  }
}
