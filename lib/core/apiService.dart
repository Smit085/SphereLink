import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../data/ViewData.dart';

class ApiService {
  final String baseUrl = "http://192.168.235.87:8080/api/v1";

  Future<String> testBackend() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/test'));

      if (response.statusCode == 200) {
        print("Success");
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load test data');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<String?> validateUser(String email, String password) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/login')
            .replace(queryParameters: {'email': email, 'password': password}),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
      ).timeout(const Duration(seconds: 10)); // Add a timeout

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        print(response.body);
        if (responseData.containsKey('message') &&
            responseData['message'] == 'Login successful') {
          return 'Login successful';
        }
        return 'Login unsuccessful';
      } else if (response.statusCode == 401) {
        return 'Invalid password.';
      } else {
        print('API Error: ${response.statusCode}');
        print('API Response Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error during API call: $e');
      return null;
    }
  }

  Future<String?> signUpUser(String firstName, String lastName,
      String phoneNumber, String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/signup'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode(<String, String>{
              'firstName': firstName,
              'lastName': lastName,
              'phoneNumber': phoneNumber,
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10)); // Add a timeout

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        print(response.body);
        if (responseData.containsKey('message') &&
            responseData['message'] == 'Signup successful') {
          return 'Signup successful';
        }
        return 'Signup unsuccessful';
      } else if (response.statusCode == 409) {
        return 'User exists';
      } else {
        print('API Error: ${response.statusCode}');
        print('API Response Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error during API call: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUser(String email) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user').replace(queryParameters: {'email': email}),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
      ).timeout(const Duration(seconds: 10)); // Add a timeout

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        print('User Data: $responseData');
        return responseData;
      } else if (response.statusCode == 404) {
        print('User not found');
        return null;
      } else {
        print('API Error: ${response.statusCode}');
        print('API Response Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error during API call: $e');
      return null;
    }
  }

// Function to encode image to Base64
  String? encodeImage(File? imageFile) {
    if (imageFile == null || !imageFile.existsSync()) return null;
    return base64Encode(imageFile.readAsBytesSync());
  }

// Function to prepare JSON data for API
  Future<Map<String, dynamic>> prepareSyncData(ViewData viewData) async {
    return {
      "viewName": viewData.viewName,
      "thumbnailImage":
          encodeImage(viewData.thumbnailImage), // File type corrected
      "dateTime": viewData.dateTime.toIso8601String(),
      "panoramaImages": viewData.panoramaImages
          .map((image) => {
                "image": encodeImage(image.image), // File type corrected
                "imageName": image.imageName,
                "markers": image.markers
                    .map((marker) => {
                          "longitude": marker.longitude,
                          "latitude": marker.latitude,
                          "label": marker.label,
                          "description": marker.description,
                          "selectedIcon": marker.selectedIcon.codePoint,
                          "selectedIconColor": marker.selectedIconColor.value,
                          "nextImageId": marker.nextImageId,
                          "selectedAction": marker.selectedAction,
                          "bannerImage": encodeImage(marker.bannerImage),
                          "link": marker.link,
                        })
                    .toList(),
              })
          .toList(),
    };
  }

  Future<void> syncDataToServer(ViewData viewData) async {
    try {
      Map<String, dynamic> jsonData = await prepareSyncData(viewData);

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 200) {
        print("✅ Data successfully uploaded to the server");
      } else {
        print("❌ Failed to upload data. Status Code: ${response.statusCode}");
        print(response.body);
      }
    } catch (e) {
      print("❌ Error uploading data: $e");
    }
  }
}
