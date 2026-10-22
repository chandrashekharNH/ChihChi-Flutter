import 'package:flutter/widgets.dart';

/// The app's rounded, chunky text (iOS: `.system(size:weight:design: .rounded)`).
TextStyle kid(double size, {FontWeight weight = FontWeight.w900, Color? color, double? height, List<Shadow>? shadows}) =>
    TextStyle(fontSize: size, fontWeight: weight, color: color, height: height, shadows: shadows, fontFamilyFallback: const [
      'SF Pro Rounded',
      '.SF UI Rounded',
      'Nunito',
      'Roboto',
    ]);

/// A soft drop shadow for white text on bright backgrounds.
const softTextShadow = [Shadow(color: Color(0x40000000), blurRadius: 2, offset: Offset(0, 1))];
