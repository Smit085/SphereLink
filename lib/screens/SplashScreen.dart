import 'package:flutter/material.dart';
import 'package:spherelink/core/session.dart';
import 'package:spherelink/utils/appColors.dart';
import 'LoginScreen.dart';
import 'MainScreen.dart';
import 'package:gif/gif.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    _startAnimations();
  }

  void _startAnimations() async {
    final session = Session();
    final isLoggedIn = await session.isUserLoggedIn();
    final nextScreen = isLoggedIn ? const MainScreen() : const LoginScreen();

    await Future.delayed(const Duration(milliseconds: 3500));

    if (!mounted) return;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _animation =
        Tween<double>(begin: 1.0, end: MediaQuery.of(context).size.height)
            .animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    setState(() {});

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => nextScreen),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Gif(
              width: 250,
              image: const AssetImage("assets/gif_splashScreen.gif"),
              autostart: Autostart.once,
              fit: BoxFit.cover,
            ),
            if (_animation != null)
              AnimatedBuilder(
                animation: _animation!,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _animation!.value,
                    child: const CircleAvatar(
                      radius: 1, // Start small
                      backgroundColor: AppColors.appprimaryColor,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
