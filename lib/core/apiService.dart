import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../data/ViewData.dart';

class ApiService {
  final String baseUrl = "http://192.168.235.87:8080/api/v1";

  /// Test API Connection
  Future<String> testBackend() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/test'));

      if (response.statusCode == 200) {
        print("Success: ${response.body}");
        return response.body.toString(); // Ensure it's always a String
      } else {
        throw Exception('Failed to load test data');
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Secure Login (Changed from GET to POST)
  Future<String?> validateUser(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);
          print("Login Response: ${response.body}");

          return responseData['message'] == 'Login successful'
              ? 'Login successful'
              : 'Login unsuccessful';
        } catch (e) {
          return 'Error parsing response';
        }
      } else if (response.statusCode == 401) {
        return 'Invalid password.';
      } else {
        print('API Error: ${response.statusCode}');
        print('🔍 Response: ${response.body}');
        return 'Unknown error occurred';
      }
    } catch (e) {
      print('Error during API call: $e');
      return 'Network error';
    }
  }

  /// User Signup
  Future<String?> signUpUser(String firstName, String lastName,
      String phoneNumber, String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/signup'),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({
              'firstName': firstName,
              'lastName': lastName,
              'phoneNumber': phoneNumber,
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        try {
          final responseData = jsonDecode(response.body);
          print("Signup Response: ${response.body}");
          return responseData['message'] == 'Signup successful'
              ? 'Signup successful'
              : 'Signup unsuccessful';
        } catch (e) {
          return 'Error parsing response';
        }
      } else if (response.statusCode == 409) {
        return 'User already exists';
      } else {
        print('API Error: ${response.statusCode}');
        print('🔍 Response: ${response.body}');
        return 'Signup failed';
      }
    } catch (e) {
      print('Error during API call: $e');
      return 'Network error';
    }
  }

  /// Fetch User Data
  Future<Map<String, dynamic>?> getUser(String email) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user').replace(queryParameters: {'email': email}),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);
          print("User Data: $responseData");
          return responseData;
        } catch (e) {
          print('Error parsing user data');
          return null;
        }
      } else if (response.statusCode == 404) {
        print('User not found');
        return null;
      } else {
        print('API Error: ${response.statusCode}');
        print('🔍 Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error during API call: $e');
      return null;
    }
  }

  // Encode Image to Base64
  String? encodeImage(File? imageFile) {
    if (imageFile == null || !imageFile.existsSync()) return null;
    return base64Encode(imageFile.readAsBytesSync());
  }

  List<String>? encodeImages(List<File?>? imageFiles) {
    if (imageFiles == null || imageFiles.isEmpty) return null;

    return imageFiles
        .where((file) =>
            file != null &&
            file.existsSync()) // Remove nulls & non-existing files
        .map((file) => base64Encode(file!.readAsBytesSync()))
        .toList();
  }

  /// Prepare JSON Data for API
  Future<Map<String, dynamic>> prepareSyncData(ViewData viewData) async {
    return {
      "viewName": viewData.viewName,
      "thumbnailImage": encodeImage(viewData.thumbnailImage),
      "dateTime": viewData.dateTime.toIso8601String(),
      "panoramaImages": viewData.panoramaImages
          .map((image) => {
                "image": encodeImage(image.image),
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
                          "bannerImage": encodeImages(marker.bannerImage),
                          "link": marker.link,
                        })
                    .toList(),
              })
          .toList(),
    };
  }

  /// Sync Data to Server (Fixed endpoint)
  Future<void> syncDataToServer(ViewData viewData) async {
    try {
      Map<String, dynamic> jsonData = await prepareSyncData(viewData);

      final response = await http
          .post(
            Uri.parse('$baseUrl/sync'), // Corrected API endpoint
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(jsonData),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print("Data successfully uploaded to the server");
      } else {
        print("Failed to upload data. Status Code: ${response.statusCode}");
        print('🔍 Response: ${response.body}');
      }
    } catch (e) {
      print("Error uploading data: $e");
    }
  }
}
