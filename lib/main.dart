import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:your_creative_notebook/screens/welcome_screen.dart';
import 'package:your_creative_notebook/screens/register_screen.dart';
import 'package:your_creative_notebook/screens/login_screen.dart';
import 'package:your_creative_notebook/screens/home_screen.dart';
import 'package:your_creative_notebook/services/pocketbase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  
  await PocketbaseService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Your Creative Notebook',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF6A5ACD),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6A5ACD),
          primary: const Color(0xFF6A5ACD),
          secondary: const Color(0xFF7B68EE),
          tertiary: const Color(0xFFFFD700),
          background: Colors.white,
        ),
      ),
      initialRoute: '/login', // Mulai dari login untuk memastikan autentikasi
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/register': (context) => const RegisterScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}