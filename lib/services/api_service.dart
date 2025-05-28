import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:your_creative_notebook/models/user.dart'; // Sesuaikan dengan nama package Anda

class ApiService {
  // Konfigurasi API - sebaiknya di .env file atau constants
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  // Headers umum untuk request API
  static Future<Map<String, String>> _getHeaders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('auth_token');

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': token != null ? 'Bearer $token' : '',
    };
  }

  // Fungsi untuk mengambil profile user
  static Future<User> fetchProfile() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/profile'),
        headers: headers,
      );
      print(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return User.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('Sesi habis. Silakan login kembali.');
      } else {
        throw Exception('Gagal memuat profil: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
