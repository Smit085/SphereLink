import 'dart:async';

import 'package:android_intent_plus/android_intent.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:spherelink/screens/ExploreScreen.dart';
import 'package:spherelink/screens/HomeScreen.dart';
import 'package:spherelink/screens/ProfileScreen.dart';
import '../core/session.dart';
import '../utils/appColors.dart';
import '../widget/BadgeNotificationIcon.dart';
import '../widget/customSnackbar.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String _currentLocation = "Tap to fetch location";
  String _username = "Guest User";
  String? profileImageUrl;

  static final List<Widget> _widgetOptions = <Widget>[
    const HomeScreen(),
    const ExploreScreen(),
    const ProfileScreen(),
  ];

  StreamSubscription<Position>? _positionStream;

  Timer? _loadingAnimationTimer;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
    _fetchUsername();
  }

  Future<void> _fetchUsername() async {
    String? firstName = await Session().getSession();
    String? lastName = await Session().getLastName();
    profileImageUrl = await Session().getProfileImagePath();
    if (mounted) {
      setState(() {
        _username = "$firstName $lastName" ?? "Guest User";
      });
    }
  }

  void _startLocationUpdates() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.medium),
    ).listen((Position position) {
      _updateLocation(position);
    }, onError: (error) {
      // Handle errors
      print("Location stream error: $error");
    });
  }

  void _updateLocation(Position position) async {
    try {
      Session().saveUserLastLocation(position.latitude, position.longitude);
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks[0];
        setState(() {
          _currentLocation =
              "${placemark.locality}, ${placemark.administrativeArea}, ${placemark.country}";
        });
      }
    } catch (e) {
      print("Error getting placemark: $e");
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _openAppInfo() async {
    const intent = AndroidIntent(
      action: "android.settings.APPLICATION_DETAILS_SETTINGS",
      package: 'com.example.spherelink',
      data: 'package:com.example.spherelink',
    );
    await intent.launch();
  }

  Future<void> _openNetworkSettings() async {
    const intent = AndroidIntent(
      action: "android.settings.AIRPLANE_MODE_SETTINGS",
    );
    await intent.launch();
  }

  void _startLocationAnimation() {
    _loadingAnimationTimer?.cancel();
    _dotCount = 0;

    setState(() {
      _currentLocation = "Fetching location.";
    });

    _loadingAnimationTimer =
        Timer.periodic(const Duration(milliseconds: 300), (timer) {
      setState(() {
        _dotCount = (_dotCount + 1) % 4; // Cycle between 0, 1, 2, 3 dots
        _currentLocation = "Fetching location${"." * _dotCount}";
      });
    });
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _currentLocation = "Fetching location...";
    });
    _startLocationAnimation();

    try {
      bool internet = await InternetConnection().hasInternetAccess;
      if (!internet) {
        showCustomSnackBar(
            context,
            AppColors.textColorPrimary,
            "Internet connection is required.",
            Colors.white,
            "Settings",
            _openNetworkSettings);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _currentLocation = "Location permission denied.";
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _currentLocation = "Location Permission denied.";
        });
        showCustomSnackBar(
            context,
            AppColors.textColorPrimary,
            "Location permission denied.",
            Colors.white,
            "Settings",
            _openAppInfo);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks[0];
        setState(() {
          _currentLocation =
              "${placemark.locality}, ${placemark.administrativeArea}, ${placemark.country}";
        });
      } else {
        throw Exception('Could not determine location.');
      }
    } catch (e) {
      setState(() {
        _currentLocation = "Unable to fetch location, Try again!";
      });
    } finally {
      _loadingAnimationTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          titleSpacing: 0,
          toolbarHeight: 60,
          backgroundColor: AppColors.appprimaryColor,
          actions: [
            const BadgeNotificationIcon(
              icon: Icons.notifications,
              notificationCount: 1,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GestureDetector(
                onTap: () {
                  // Handle profile button tap
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: profileImageUrl != null
                      ? CachedNetworkImageProvider(
                          profileImageUrl!,
                        )
                      : const AssetImage('assets/profile_1.jpeg'),
                  child: profileImageUrl == null
                      ? const Center(
                          child: SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ],
          title: _AppBarTitle(
            username: _username,
            location: _currentLocation,
            onRefresh: _fetchLocation,
          ),
        ),
        backgroundColor: AppColors.appprimaryColor,
        body: IndexedStack(
          index: _selectedIndex,
          children: _widgetOptions,
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: AppColors.appsecondaryColor,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(icon: Icons.home, index: 0, label: "Home"),
          _buildNavItem(icon: Icons.explore, index: 1, label: "Explore"),
          _buildNavItem(icon: Icons.person, index: 2, label: "Profile"),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      {required IconData icon, required int index, required String label}) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        splashColor: AppColors.appprimaryColor.withOpacity(0.2),
        highlightColor: Colors.transparent,
        child: Container(
          color: AppColors.appsecondaryColor,
          height: 70,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isSelected
                      ? AppColors.appsecondaryColor
                      : Colors.transparent,
                  shape: BoxShape.rectangle,
                ),
                // padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: Icon(
                        icon,
                        key: ValueKey<bool>(isSelected),
                        size: isSelected ? 32.0 : 28.0,
                        color: isSelected ? Colors.white : Colors.grey,
                      ),
                    ),
                    if (isSelected)
                      Text(
                        label,
                        style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey,
                            fontSize: 9),
                        // key: ValueKey<bool>(isSelected),
                      ),
                    Stack(
                      children: [
                        Container(
                          height: 3,
                          width: 35,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          width: isSelected ? 35 : 0,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.textColorPrimary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}

class _AppBarTitle extends StatelessWidget {
  final String username;
  final String location;
  final VoidCallback onRefresh;

  const _AppBarTitle({
    required this.username,
    required this.location,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(Icons.my_location_outlined, color: Colors.white),
        ),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              username,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 3),
            Text(
              location,
              style: TextStyle(
                color: location == "Unable to fetch location"
                    ? Colors.red[300]
                    : Colors.white70,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ))
      ],
    );
  }
}
