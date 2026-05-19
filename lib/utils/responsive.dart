import 'package:flutter/material.dart';

class Responsive {
  static MediaQueryData? _mediaQuery;
  static double screenWidth = 390;
  static double screenHeight = 844;
  static double statusBarHeight = 0;
  static double bottomNavHeight = 0;
  static double _textScaleFactor = 1;

  static void init(BuildContext context) {
    _mediaQuery = MediaQuery.of(context);
    screenWidth = _mediaQuery!.size.width;
    screenHeight = _mediaQuery!.size.height;
    statusBarHeight = _mediaQuery!.padding.top;
    bottomNavHeight = _mediaQuery!.padding.bottom;
    _textScaleFactor = _mediaQuery!.textScaler
        .scale(1)
        .clamp(0.8, 1.3)
        .toDouble();
  }

  static double w(double percent) => screenWidth * percent / 100;

  static double h(double percent) => screenHeight * percent / 100;

  static double sp(double size) =>
      size * (screenWidth / 390) * _textScaleFactor;

  static bool get isSmall => screenWidth < 360;

  static bool get isLarge => screenWidth > 420;

  static double get avatarSize => isSmall
      ? 40
      : isLarge
      ? 56
      : 48;

  static double get bubbleMaxWidth => screenWidth * 0.75;

  static double get inputBarHeight => isSmall ? 52 : 60;
}
