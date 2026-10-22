import 'package:flutter/painting.dart';

/// `rgb(0.18, 0.65, 0.28)`: a colour from 0…1 channels, like SwiftUI's `Color(red:green:blue:)`.
Color rgb(double r, double g, double b, [double a = 1]) =>
    Color.fromRGBO((r * 255).round(), (g * 255).round(), (b * 255).round(), a);

extension ColorOpacity on Color {
  /// SwiftUI's `.opacity(x)`.
  Color opacity(double value) => withValues(alpha: value);
}
