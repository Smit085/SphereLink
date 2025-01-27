import 'package:shared_preferences/shared_preferences.dart';

class Session {
  Future<void> saveSession(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
  }

  // Retrieve token or session data
  Future<String?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
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
