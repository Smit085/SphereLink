import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart'; // Add this for MediaType
import 'package:spherelink/core/session.dart';
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

  Future<bool> syncDataToServer(ViewData view) async {
    try {
      // Prepare metadata
      String? token = await Session().getUserToken();
      print("Token: ${token ?? "No token available"}");

      Map<String, dynamic> metadata = {
        "viewName": view.viewName ?? "Untitled View",
        "dateTime": view.dateTime?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        "description": view.description ?? "",
        "location": view.location ?? 0.0
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

      // Add panorama images, markers, and banner images
      for (int i = 0; i < view.panoramaImages.length; i++) {
        final panoImage = view.panoramaImages[i];
        Uint8List? originalImage = await getOriginalImage(panoImage.image);

        if (originalImage != null) {
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

        // Add markers data
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

        // Add banner images (new part)
        for (int j = 0; j < panoImage.markers.length; j++) {
          final marker = panoImage.markers[j];
          if (marker.bannerImage != null) {
            for (int k = 0; k < (marker.bannerImage?.length ?? 0); k++) {
              final bannerFile = marker.bannerImage?[k];
              if (bannerFile != null) {
                Uint8List? bannerBytes = await getOriginalImage(bannerFile);
                if (bannerBytes != null) {
                  formData.files.add(MapEntry(
                    'bannerImage_${i}_${j}_$k',
                    MultipartFile.fromBytes(
                      bannerBytes,
                      filename: 'bannerImage_${i}_${j}_$k.jpg',
                      contentType: MediaType('image', 'jpeg'),
                    ),
                  ));
                  print('Added banner image for marker $j at panorama $i:');
                  print('  Key: bannerImage_${i}_${j}_$k');
                  print('  Filename: bannerImage_${i}_${j}_$k.jpg');
                  print('  Size: ${bannerBytes.length} bytes');
                }
              }
            }
          }
        }
      }

      // Add metadata
      formData.fields.add(MapEntry('metadata', jsonEncode(metadata)));

      print('FormData contents:');
      print('Files: ${formData.files.length}');
      formData.files
          .forEach((entry) => print('  ${entry.key}: ${entry.value.filename}'));
      print('Fields: ${formData.fields.length}');
      formData.fields
          .forEach((entry) => print('  ${entry.key}: ${entry.value}'));

      final response = await _dio.post(
        "$baseUrl/views",
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
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
        print("Data uploaded successfully");
        return true;
      } else {
        print("Upload failed. Status: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Error uploading: $e");
      if (e is DioException) {
        print('Dio error response: ${e.response?.data}');
        print('Dio error status: ${e.response?.statusCode}');
        if (e.response?.statusCode == 413) {
          print("Upload size too large!");
        }
      }
      return false;
    }
  }

  Future<List<ViewData>> fetchPublishedViews() async {
    String? token = await Session().getUserToken();
    print("Token: ${token ?? "No token available"}");

    final url = Uri.parse('$baseUrl/views');
    print('Requesting: $url'); // Debug
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    print('Status: ${response.statusCode}, Body: ${response.body}'); // Debug
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      final List<dynamic> viewsJson = jsonData['data'];
      return viewsJson.map((json) => ViewData.fromJson(json)).toList();
    } else {
      throw Exception(
          'Failed to load views: ${response.statusCode} - ${response.body}');
    }
  }

  Future<bool> updateUserProfile({
    required String firstName,
    required String lastName,
    required String phoneNumber,
    File? profileImage,
  }) async {
    try {
      String? token = await Session().getUserToken();
      print("Token: ${token ?? "No token available"}");

      FormData formData = FormData();

      // Add text fields
      formData.fields.addAll([
        MapEntry('firstName', firstName),
        MapEntry('lastName', lastName),
        MapEntry('phoneNumber', phoneNumber),
      ]);

      // Add profile image if provided
      if (profileImage != null && await profileImage.exists()) {
        Uint8List? imageBytes = await getOriginalImage(profileImage);
        if (imageBytes != null) {
          formData.files.add(MapEntry(
            'profileImage',
            MultipartFile.fromBytes(
              imageBytes,
              filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
              contentType: MediaType('image', 'jpeg'),
            ),
          ));
          print('Profile image size: ${imageBytes.length} bytes');
        }
      }

      final response = await _dio.put(
        "$baseUrl/users/profile",
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      print('Response status: ${response.statusCode}');
      print('Response data: ${response.data}');

      return response.statusCode == 200;
    } catch (e) {
      print("Error updating profile: $e");
      if (e is DioException) {
        print('Dio error response: ${e.response?.data}');
        print('Dio error status: ${e.response?.statusCode}');
      }
      return false;
    }
  }

  Future<bool> deleteView(String viewId) async {
    try {
      String? token = await Session().getUserToken();
      print("Token: ${token ?? "No token available"}");

      final response = await _dio.delete(
        "$baseUrl/views/$viewId",
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      print('Response status: ${response.statusCode}');
      print('Response data: ${response.data}');
      return response.statusCode == 200;
    } catch (e) {
      print("Error deleting view: $e");
      if (e is DioException) {
        print('Dio error response: ${e.response?.data}');
        print('Dio error status: ${e.response?.statusCode}');
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
