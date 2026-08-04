import 'package:flutter/material.dart';

class Responsive {
  static double screenWidth = 390;
  static double screenHeight = 844;
  static double statusBarHeight = 0;
  static double bottomNavHeight = 0;
  static double _textScaleFactor = 1;

  static void init(BuildContext context) {
    // Depend ONLY on the fields we actually read (size, padding, textScaler).
    // Using MediaQuery.of(context) here would subscribe the calling widget to
    // the *entire* MediaQueryData  including viewInsets, which changes on every
    // frame of the keyboard open/close animation. That makes the whole screen
    // rebuild ~60x while the keyboard slides in, causing visible jank.
    // The granular *Of(context) accessors only notify when their own field changes.
    //
    // We read viewPadding (NOT padding) for the status/nav-bar insets: `padding`
    // is `viewPadding` minus `viewInsets`, so its bottom collapses to 0 as the
    // keyboard crosses the nav bar  which would still rebuild the screen every
    // keyboard frame. `viewPadding` is the physical inset and stays constant
    // while the keyboard animates, so the screen no longer rebuilds with it.
    final Size size = MediaQuery.sizeOf(context);
    final EdgeInsets padding = MediaQuery.viewPaddingOf(context);
    final TextScaler textScaler = MediaQuery.textScalerOf(context);

    screenWidth = size.width;
    screenHeight = size.height;
    statusBarHeight = padding.top;
    bottomNavHeight = padding.bottom;
    _textScaleFactor = textScaler.scale(1).clamp(0.8, 1.3).toDouble();
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
