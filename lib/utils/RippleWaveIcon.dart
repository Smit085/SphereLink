import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class RippleWaveIcon extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final Duration rippleDuration;
  final Color iconColor;
  final Color rippleColor;
  final VoidCallback onTap;

  const RippleWaveIcon({
    super.key,
    required this.icon,
    this.iconSize = 40,
    this.iconColor = Colors.white,
    this.rippleColor = Colors.blue,
    this.rippleDuration = const Duration(milliseconds: 2000),
    required this.onTap,
  });

  @override
  _RippleWaveIconState createState() => _RippleWaveIconState();
}

class _RippleWaveIconState extends State<RippleWaveIcon>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  List<Animation<double>> _rippleAnimations = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.rippleDuration,
    )..repeat();

    for (int i = 0; i < 3; i++) {
      _rippleAnimations.add(Tween<double>(begin: 0, end: 2).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(i * 0.2, 1, curve: Curves.easeOut),
        ),
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ripples
          for (var animation in _rippleAnimations)
            AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                return OverflowBox(
                  maxWidth: 90,
                  maxHeight: 90,
                  child: Container(
                    width: 45 * animation.value,
                    height: 45 * animation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.rippleColor
                          .withOpacity((1.2 - animation.value).clamp(0.0, 1.0)),
                    ),
                  ),
                );
              },
            ),
          // Clickable Icon
          Container(
            width: widget.iconSize / 2,
            height: widget.iconSize / 2,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
          ),
          Icon(
            // Remove Center widget
            widget.icon,
            color: widget.iconColor,
            size: widget.iconSize,
          ),
        ],
      ),
    );
  }
}
