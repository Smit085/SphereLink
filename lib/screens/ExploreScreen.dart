import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spherelink/utils/appColors.dart';
import '../utils/RippleWaveIcon.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  bool _isSheetVisible = false;
  double _sheetHeightFactor = 0.0;
  final double _minSheetHeightFactor = 0.2;
  final double _halfSheetHeightFactor = 0.5;
  final double _maxSheetHeightFactor = 0.9;

  @override
  void initState() {
    print("Hello");
    super.initState();
  }

  void _openSheet() {
    setState(() {
      _isSheetVisible = true;
      _sheetHeightFactor = _minSheetHeightFactor;
    });
  }

  void _closeSheetFully() {
    setState(() {
      _isSheetVisible = false;
      _sheetHeightFactor = 0.0;
    });
  }

  void _toggleSheet() {
    setState(() {
      if (_sheetHeightFactor == 0) {
        _openSheet();
      } else if (_sheetHeightFactor == _minSheetHeightFactor) {
        _sheetHeightFactor = _halfSheetHeightFactor;
      } else if (_sheetHeightFactor == _halfSheetHeightFactor) {
        _sheetHeightFactor = _maxSheetHeightFactor;
      } else {
        _sheetHeightFactor = _minSheetHeightFactor;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final sheetWidth = isLandscape
        ? MediaQuery.of(context).size.width / 2
        : MediaQuery.of(context).size.width;
    final sheetLeft = isLandscape ? 0 : 0;

    return WillPopScope(
      onWillPop: () async {
        if (_isSheetVisible) {
          _closeSheetFully();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.appprimaryBackgroundColor,
        body: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Center(
                  child: Text(
                    "Explore Screen",
                    style: TextStyle(fontSize: 24),
                  ),
                ),
                GestureDetector(
                  onTap: _openSheet,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.appsecondaryColor,
                      borderRadius: BorderRadius.circular(45),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 5,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                    child: Center(
                        child: RippleWaveIcon(
                      icon: Icons.info,
                      onTap: _openSheet,
                      rippleColor: Colors.blue,
                      iconSize: 15,
                      iconColor: Colors.white,
                      rippleDuration: const Duration(seconds: 3),
                    )),
                  ),
                ),
              ],
            ),
            if (_isSheetVisible)
              GestureDetector(
                  onTap: _closeSheetFully,
                  child: Container(color: Colors.black.withOpacity(0.3))),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: sheetLeft.toDouble(),
              bottom: _isSheetVisible
                  ? 0
                  : -MediaQuery.of(context).size.height * _minSheetHeightFactor,
              width: sheetWidth,
              height: MediaQuery.of(context).size.height * _sheetHeightFactor,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  setState(() {
                    double newHeight = _sheetHeightFactor -
                        details.primaryDelta! /
                            MediaQuery.of(context).size.height;
                    _sheetHeightFactor = newHeight.clamp(
                        _minSheetHeightFactor, _maxSheetHeightFactor);
                  });
                },
                onVerticalDragEnd: (details) {
                  double velocity = details.primaryVelocity ?? 0;
                  if (velocity > 500 || _sheetHeightFactor < 0.15) {
                    _closeSheetFully();
                  } else if (velocity < -500 || _sheetHeightFactor > 0.75) {
                    _sheetHeightFactor = _maxSheetHeightFactor;
                  } else if (_sheetHeightFactor > 0.35) {
                    _sheetHeightFactor = _halfSheetHeightFactor;
                  } else {
                    _sheetHeightFactor = _minSheetHeightFactor;
                  }
                  setState(() {});
                },
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(25),
                        topRight: Radius.circular(25),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _toggleSheet,
                          child: Container(
                            width: 50,
                            height: 4,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            children: const [
                              ListTile(title: Text('Option 1')),
                              ListTile(title: Text('Option 2')),
                              ListTile(title: Text('Option 3')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
