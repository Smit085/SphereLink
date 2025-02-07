import 'package:shared_preferences/shared_preferences.dart';

class UserSettings {
  Future<void> saveViewType(bool isListView) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isListView', isListView);
  }

  Future<bool?> getViewType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isListView');
  }
}
