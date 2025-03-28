import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:mappls_gl/mappls_gl.dart';
import 'package:spherelink/screens/ExploreScreen.dart';
import 'package:spherelink/screens/LoginScreen.dart';
import 'package:spherelink/screens/MainScreen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:spherelink/screens/PanoramicWithMarkers.dart';
import 'package:spherelink/screens/PublishViewScreen.dart';
import 'package:spherelink/screens/SplashScreen.dart';

import 'core/AppConfig.dart';

void main() {
  final ImagePickerPlatform imagePickerImplementation =
      ImagePickerPlatform.instance;
  if (imagePickerImplementation is ImagePickerAndroid) {
    imagePickerImplementation.useAndroidPhotoPicker = true;
  }
  runApp(const SphereLink());
}

class SphereLink extends StatelessWidget {
  const SphereLink({super.key});
  @override
  Widget build(BuildContext context) {
    debugPaintSizeEnabled = false;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // MapmyIndia Setup
    MapplsAccountManager.setMapSDKKey(AppConfig.mapSDKKey);
    MapplsAccountManager.setRestAPIKey(AppConfig.restAPIKey);
    MapplsAccountManager.setAtlasClientId(AppConfig.atlasClientId);
    MapplsAccountManager.setAtlasClientSecret(AppConfig.atlasClientSecret);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SphereLink',
      home: const MainScreen(),
      theme: ThemeData(
        appBarTheme: const AppBarTheme(),
      ),
    );
  }
}
