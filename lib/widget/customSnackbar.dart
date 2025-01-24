import 'package:flutter/material.dart';

import '../utils/appColors.dart';

void showCustomSnackBar(
  context,
  Color color,
  String message,
  String btnText,
  Function() onTap,
) {
  final overlay = Overlay.of(context);

  ValueNotifier<double> scale = ValueNotifier<double>(0.95);
  ValueNotifier<double> opacity = ValueNotifier<double>(1.0);

  final snackBarOverlay = OverlayEntry(
    builder: (context) {
      return Positioned(
        left: 16,
        right: 16,
        bottom: 16,
        child: ValueListenableBuilder<double>(
          valueListenable: scale,
          builder: (context, scaleValue, child) {
            return ValueListenableBuilder<double>(
              valueListenable: opacity,
              builder: (context, opacityValue, child) {
                return AnimatedScale(
                  scale: scaleValue,
                  curve: Curves.linearToEaseOut,
                  duration: const Duration(milliseconds: 150),
                  child: AnimatedOpacity(
                    opacity: opacityValue,
                    duration: const Duration(milliseconds: 125),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              message!,
                              style: const TextStyle(color: Colors.black),
                            ),
                            if (btnText != null)
                              TextButton(
                                style: ButtonStyle(
                                  overlayColor: WidgetStateProperty.all(
                                      Colors.transparent),
                                ),
                                onPressed: onTap,
                                child: Text(
                                  btnText,
                                  style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    },
  );

  overlay.insert(snackBarOverlay);

  // Trigger the scale animation.
  Future.delayed(const Duration(milliseconds: 50), () {
    scale.value = 1.0;
  });

  // Trigger the fade-out animation before removal.
  Future.delayed(const Duration(seconds: 2), () {
    opacity.value = 0.0;
  });

  // Remove the snackbar from the overlay after fade-out completes.
  Future.delayed(const Duration(seconds: 2, milliseconds: 500), () {
    snackBarOverlay.remove();
  });
}
