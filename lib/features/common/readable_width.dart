import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The widest a list of cards should get. On wider screens (tablets) the extra space
/// becomes side margins so rows don't stretch across the whole display.
const double readableMaxWidth = 900;

/// List padding that keeps content at most [readableMaxWidth] wide and centered.
EdgeInsets readablePadding(BuildContext context, {double horizontal = 16, double top = 16, double bottom = 16}) {
  final side = math.max(horizontal, (MediaQuery.sizeOf(context).width - readableMaxWidth) / 2);
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}
