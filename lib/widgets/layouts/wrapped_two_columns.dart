import 'dart:math';

import 'package:flutter/material.dart';

class WidgetsLayoutsWrappedTwoColumns extends MultiChildLayoutDelegate {
  final void Function(bool shouldWrap) onWrapChanged;
  final double currentHeight;

  WidgetsLayoutsWrappedTwoColumns({required this.onWrapChanged, required this.currentHeight});

  bool _shouldWrap = false;

  @override
  void performLayout(Size size) {
    Size left = layoutChild('left', BoxConstraints.loose(size));
    Size right = layoutChild('right', BoxConstraints.loose(size));
    Size middle = layoutChild('middle', BoxConstraints.loose(size));
    Size trailing = layoutChild('trailing', BoxConstraints.loose(size));

    double row1Height = [left.height, right.height, trailing.height].reduce(max);
    _shouldWrap = (left.width + middle.width + right.width + trailing.width + 70) > size.width;

    if (!_shouldWrap) {
      positionChild('left', Offset.zero);
      positionChild('middle', Offset(left.width + 30, 0));
      positionChild('right', Offset(size.width - trailing.width - right.width, 0));
      positionChild('trailing', Offset(size.width - trailing.width, 0));
    } else {
      positionChild('left', Offset.zero);
      positionChild('right', Offset(size.width - trailing.width - right.width, 0));
      positionChild('trailing', Offset(size.width - trailing.width, 0));

      const double gap = 16.0;
      positionChild('middle', Offset(0, row1Height + gap));
    }

    onWrapChanged(_shouldWrap);
  }

  @override
  Size getSize(BoxConstraints constraints) {
    return Size(constraints.maxWidth, currentHeight);
  }

  @override
  bool shouldRelayout(WidgetsLayoutsWrappedTwoColumns oldDelegate) => true;
}
