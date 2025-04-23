import 'dart:ffi';

import 'package:mappls_gl/mappls_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Session {
  Future<void> saveFirstName(String firstName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('firstName', firstName);
  }

  Future<String?> getFirstName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('firstName');
  }

  Future<void> saveLastName(String lastName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastName', lastName);
  }

  Future<String?> getLastName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('lastName');
  }

  Future<void> savePhone(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phoneNumber', phoneNumber);
  }

  Future<String?> getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('phoneNumber');
  }

  Future<void> saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('email', email);
  }

  Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('email');
  }

  Future<void> saveProfileImagePath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profileImagePath', path!);
  }

  Future<String?> getProfileImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('profileImagePath');
  }

  Future<void> saveUserLastLocation(double latitude, double longitude) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('latitude', latitude.toString());
    await prefs.setString('longitude', longitude.toString());
  }

  Future<LatLng> getUserLastLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final latitudeString = prefs.getString('latitude');
    final longitudeString = prefs.getString('longitude');

    if (latitudeString != null && longitudeString != null) {
      final latitude = double.parse(latitudeString);
      final longitude = double.parse(longitudeString);
      return LatLng(latitude, longitude);
    }
    return const LatLng(26.7957, 82.1944);
  }

  Future<bool> isUserLoggedIn() async {
    final firstName = await getFirstName();
    return firstName != null;
  }

  Future<void> saveUserToken(token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userToken', token);
  }

  Future<String?> getUserToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userToken');
  }

  // Clear session data
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('firstName');
  }
}
