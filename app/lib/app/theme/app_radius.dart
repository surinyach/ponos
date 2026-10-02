import 'package:flutter/widgets.dart';

/// Shape tokens from the approved Ponos references.
abstract final class AppRadius {
  static const double small = 8;
  static const double controlValue = 10;
  static const double cardValue = 16;
  static const double full = 999;

  static const control = BorderRadius.all(Radius.circular(controlValue));
  static const card = BorderRadius.all(Radius.circular(cardValue));
  static const pill = BorderRadius.all(Radius.circular(full));

  // Compatibility aliases used by existing feature widgets.
  static const double medium = controlValue;
  static const double large = cardValue;
}
