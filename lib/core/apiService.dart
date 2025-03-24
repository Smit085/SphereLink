import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart'; // Add this for MediaType
import '../data/ViewData.dart';
import 'AppConfig.dart';

class ApiService {
  String baseUrl = AppConfig.apiBaseUrl;
  final Dio _dio = Dio();

  ApiService() {
    _dio.interceptors.add(RetryInterceptor(
      dio: _dio,
      retries: 3,
      retryDelays: const Duration(seconds: 2),
    ));
  }

  /// Test API Connection
  Future<String> testBackend() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/test'));
      if (response.statusCode == 200) {
        print("Success: ${response.body}");
        return response.body;
      } else {
        throw Exception('Failed to load test data');
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// User Login
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
        final responseData = jsonDecode(response.body);
        print("Login Response: ${response.body}");
        return responseData['message'] == 'Login successful'
            ? 'Login successful'
            : 'Login unsuccessful';
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
      String phoneNumber, String emailId, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/signup'),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({
              'firstName': firstName,
              'lastName': lastName,
              'phoneNumber': phoneNumber,
              'emailId': emailId,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print("Signup Response: ${response.body}");
        return responseData['message'] == 'Signup successful'
            ? 'Signup successful'
            : 'Signup unsuccessful';
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
        final responseData = jsonDecode(response.body);
        print("User Data: $responseData");
        return responseData;
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

  /// Get Original Image Bytes
  Future<Uint8List?> getOriginalImage(File? imageFile) async {
    if (imageFile == null || !await imageFile.exists()) return null;
    try {
      final bytes = await imageFile.readAsBytes();
      print('Original image size: ${bytes.length} bytes');
      return bytes;
    } catch (e) {
      print('Error reading image file: $e');
      return null;
    }
  }

  /// Sync Data to Server
  Future<bool> syncDataToServer(ViewData view) async {
    try {
      // Prepare metadata
      Map<String, dynamic> metadata = {
        "viewName": view.viewName,
        "dateTime": view.dateTime.toIso8601String(),
      };

      FormData formData = FormData();

      // Add thumbnail image
      Uint8List? originalThumbnail =
          await getOriginalImage(view.thumbnailImage);
      if (originalThumbnail != null) {
        formData.files.add(MapEntry(
          'thumbnailImage',
          MultipartFile.fromBytes(
            originalThumbnail,
            filename: 'thumbnail_${view.viewName}.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        ));
        print('Thumbnail size: ${originalThumbnail.length} bytes');
      }

      // Add panorama images and markers
      for (int i = 0; i < view.panoramaImages.length; i++) {
        final panoImage = view.panoramaImages[i];
        Uint8List? originalImage = await getOriginalImage(panoImage.image);

        if (originalImage != null) {
          // Simplified key name and added detailed logging
          String fileKey = 'panoramaImage_$i';
          formData.files.add(MapEntry(
            fileKey,
            MultipartFile.fromBytes(
              originalImage,
              filename: '${panoImage.imageName}.jpg',
              contentType: MediaType('image', 'jpeg'),
            ),
          ));
          print('Added panorama image $i:');
          print('  Key: $fileKey');
          print('  Filename: ${panoImage.imageName}.jpg');
          print('  Size: ${originalImage.length} bytes');
        } else {
          print('Warning: No image data for panorama $i');
        }

        // Store metadata separately with clear indexing
        formData.fields.add(MapEntry(
          'panorama[$i][imageName]',
          panoImage.imageName,
        ));
        formData.fields.add(MapEntry(
          'panorama[$i][markers]',
          jsonEncode(panoImage.markers
              .map((marker) => {
                    "longitude": marker.longitude,
                    "latitude": marker.latitude,
                    "label": marker.label,
                    "subTitle": marker.subTitle,
                    "description": marker.description,
                    "address": marker.address,
                    "phoneNumber": marker.phoneNumber,
                    "selectedIconStyle": marker.selectedIconStyle,
                    "selectedIcon": marker.selectedIcon.codePoint,
                    "selectedIconColor": marker.selectedIconColor.value,
                    "nextImageId": marker.nextImageId,
                    "selectedIconRotationRadians":
                        marker.selectedIconRotationRadians.toString(),
                    "selectedAction": marker.selectedAction,
                    "link": marker.link,
                  })
              .toList()),
        ));
      }

      formData.fields.add(MapEntry('metadata', jsonEncode(metadata)));

      print('FormData contents:');
      print('Files: ${formData.files.length}');
      formData.files
          .forEach((entry) => print('  ${entry.key}: ${entry.value.filename}'));
      print('Fields: ${formData.fields.length}');
      formData.fields
          .forEach((entry) => print('  ${entry.key}: ${entry.value}'));

      final response = await _dio.post(
        'https://webhook.site/f97db724-a5b4-4579-808c-65320902072d',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
            'Accept': 'application/json',
          },
        ),
        onSendProgress: (sent, total) {
          print('Upload progress: ${(sent / total * 100).toStringAsFixed(2)}%');
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      print('Response data: ${response.data}');

      if (response.statusCode == 200) {
        print("✅ Data successfully uploaded");
        return true;
      } else {
        print("❌ Upload failed. Status: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("❌ Error uploading: $e");
      if (e is DioException) {
        print('Dio error response: ${e.response?.data}');
      }
      return false;
    }
  }
}

class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int retries;
  final Duration retryDelays;

  RetryInterceptor({
    required this.dio,
    required this.retries,
    required this.retryDelays,
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    int attempt = err.requestOptions.extra['retry_count'] ?? 0;
    if (attempt < retries) {
      print('Retrying request (${attempt + 1}/$retries)...');
      await Future.delayed(retryDelays);
      err.requestOptions.extra['retry_count'] = attempt + 1;
      try {
        final response = await dio.fetch(err.requestOptions);
        handler.resolve(response);
      } catch (e) {
        handler.next(err);
      }
    } else {
      handler.next(err);
    }
  }
}
