import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _token;

  // Fungsi untuk login
  Future<void> loginUser() async {
    final response = await http.post(
      Uri.parse('http://127.0.0.1:8000/api/login'), // Ganti dengan URL API Laravel
      body: {
        'email': _emailController.text,
        'password': _passwordController.text,
      },
    );

    if (response.statusCode == 200) {
      // Login berhasil dan dapatkan token
      final responseData = json.decode(response.body);
      setState(() {
        _token = responseData['token']; // Menyimpan token
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login successful')));
    } else {
      // Login gagal
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: loginUser,
              child: Text('Login'),
            ),
            if (_token != null)
              Text('Logged in! Token: $_token'),
          ],
        ),
      ),
    );
  }
}
