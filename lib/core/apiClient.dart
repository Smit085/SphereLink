import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // final String baseUrl = "http://localhost:8080/api";
  final String baseUrl = "http://192.168.235.87:8080/api/v1";

  Future<String> testBackend() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/test'));

      if (response.statusCode == 200) {
        print("Sucess");
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load test data');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<String> validateUser(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode(<String, String>{
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10)); // Add a timeout

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
        return 'Login unsuccessful';
      }
    } catch (e) {
      print('Error during API call: $e');
      return 'Login unsuccessful';
    }
  }
}
