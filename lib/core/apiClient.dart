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

  Future<String> lo() async {
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
}
