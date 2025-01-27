import 'package:flutter/material.dart';
import 'package:spherelink/core/session.dart';
import 'LoginScreen.dart';
import 'MainScreen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _determineInitialScreen();
  }

  Future<void> _determineInitialScreen() async {
    final session = Session();
    final isLoggedIn = await session.isUserLoggedIn();
    final nextScreen = isLoggedIn ? const MainScreen() : const LoginScreen();
    await Future.delayed(const Duration(seconds: 2));
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "SphereLink",
          style: TextStyle(fontSize: 45, color: Colors.blueAccent),
        ),
      ),
    );
  }
}
