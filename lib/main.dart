import 'package:flutter/services.dart';
import 'package:spherelink/screens/LoginScreen.dart';
import 'package:spherelink/screens/MainScreen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:spherelink/screens/SplashScreen.dart';

void main() {
  final ImagePickerPlatform imagePickerImplementation =
      ImagePickerPlatform.instance;
  if (imagePickerImplementation is ImagePickerAndroid) {
    imagePickerImplementation.useAndroidPhotoPicker = true;
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Marker App',
      home: const SplashScreen(),
      theme: ThemeData(
        appBarTheme: const AppBarTheme(),
      ),
    );
  }
}
