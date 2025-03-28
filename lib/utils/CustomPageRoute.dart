import 'package:flutter/cupertino.dart';

enum TransitionDirection {
  fromLeft,
  fromRight,
  fromTop,
  fromBottom,
}

class CustomPageRoute extends PageRouteBuilder {
  final WidgetBuilder builder;
  final TransitionDirection direction;

  CustomPageRoute({
    required this.builder,
    required this.direction,
  }) : super(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              builder(context),
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            Offset begin;
            switch (direction) {
              case TransitionDirection.fromLeft:
                begin = const Offset(-1.0, 0.0);
                break;
              case TransitionDirection.fromRight:
                begin = const Offset(1.0, 0.0);
                break;
              case TransitionDirection.fromTop:
                begin = const Offset(0.0, -1.0);
                break;
              case TransitionDirection.fromBottom:
                begin = const Offset(0.0, 1.0);
                break;
            }

            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        );
}
