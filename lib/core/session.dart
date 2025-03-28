import 'dart:ffi';

import 'package:mappls_gl/mappls_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Session {
  Future<void> saveSession(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
  }

  Future<String?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
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

  // Clear session data
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
  }

  Future<bool> isUserLoggedIn() async {
    final username = await getSession();
    return username != null;
  }
}
