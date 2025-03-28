import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:spherelink/core/AppConfig.dart';

class GoogleAuthService {
  String baseUrl = AppConfig.apiBaseUrl;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    serverClientId: AppConfig.googleServerClientId,
  );

  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      // await GoogleSignIn().disconnect();
      // await GoogleSignIn().signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      print("ID Token: ${googleAuth.idToken}");

      final response = await http.post(
        Uri.parse("$baseUrl/google"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"idToken": googleAuth.idToken}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Google Sign-In failed: ${response.body}");
        return null;
      }
    } catch (error) {
      print("Google Sign-In Error: $error");
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
