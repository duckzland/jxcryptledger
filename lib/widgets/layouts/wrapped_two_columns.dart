import 'dart:math';

import 'package:flutter/material.dart';

class WidgetsLayoutsWrappedTwoColumns extends MultiChildLayoutDelegate {
  final void Function(int totalRows, double calculatedHeight) onWrapChanged;
  final double currentHeight;

  WidgetsLayoutsWrappedTwoColumns({required this.onWrapChanged, required this.currentHeight});

  bool _shouldWrap = false;

  @override
  void performLayout(Size size) {
    Size? left, right, middle, trailing;
    int totalRows = 0;
    const double gap = 16.0;
    double currentHeight = 0;

    // If width < 800, force column layout
    if (size.width < 960) {
      if (hasChild('trailing')) {
        trailing = layoutChild('trailing', BoxConstraints(maxWidth: size.width));
        positionChild('trailing', Offset(0, 0));
        if (trailing.height > 30) {
          currentHeight += trailing.height + gap;
        }
        totalRows++;
      }

      if (hasChild('left')) {
        left = layoutChild('left', BoxConstraints(maxWidth: size.width - 30));
        positionChild('left', Offset(0, currentHeight));
        currentHeight += left.height + gap;
        totalRows++;
      }

      if (hasChild('right')) {
        right = layoutChild('right', BoxConstraints(maxWidth: size.width));
        positionChild('right', Offset(0, currentHeight));
        currentHeight += right.height + gap;
        totalRows++;
      }
      if (hasChild('middle')) {
        middle = layoutChild('middle', BoxConstraints(maxWidth: size.width));
        positionChild('middle', Offset(0, currentHeight));
        currentHeight += middle.height + gap;
        totalRows++;
      }

      currentHeight -= gap;
    } else {
      if (hasChild('left')) {
        left = layoutChild('left', BoxConstraints.loose(size));
      }

      if (hasChild('middle')) {
        middle = layoutChild('middle', BoxConstraints.loose(size));
      }

      if (hasChild('right')) {
        right = layoutChild('right', BoxConstraints.loose(size));
      }

      if (hasChild('trailing')) {
        trailing = layoutChild('trailing', BoxConstraints.loose(size));
      }

      // Safely compute row1Height
      final row1Height = [left?.height ?? 0, right?.height ?? 0, trailing?.height ?? 0].reduce(max);

      // Safely compute total width
      final totalWidth = (left?.width ?? 0) + (middle?.width ?? 0) + (right?.width ?? 0) + (trailing?.width ?? 0) + 70;

      _shouldWrap = totalWidth > size.width;

      totalRows++;
      if (!_shouldWrap) {
        if (left != null) {
          positionChild('left', Offset.zero);
        }
        if (middle != null && left != null) {
          positionChild('middle', Offset(left.width + 30, 0));
        }
        if (right != null && trailing != null) {
          positionChild('right', Offset(size.width - trailing.width - right.width, 0));
        }
        if (trailing != null) {
          positionChild('trailing', Offset(size.width - trailing.width, 0));
        }

        currentHeight = row1Height;
      } else {
        totalRows++;
        currentHeight = row1Height + gap;
        if (left != null) {
          positionChild('left', Offset.zero);
        }
        if (right != null && trailing != null) {
          positionChild('right', Offset(size.width - trailing.width - right.width, 0));
        }
        if (trailing != null) {
          positionChild('trailing', Offset(size.width - trailing.width, 0));
        }
        if (middle != null) {
          const double gap = 16.0;
          positionChild('middle', Offset(0, row1Height + gap));
          currentHeight += middle.height + gap;
        }

        currentHeight -= gap;
      }
    }

    onWrapChanged(totalRows, currentHeight);
  }
  // @override
  // Size getSize(BoxConstraints constraints) {
  //   // If stacked, compute total height dynamically
  //   if (constraints.maxWidth < 800) {
  //     const double gap = 16.0;
  //     final totalHeight =
  //         gap * 3 +
  //         layoutChild('left', BoxConstraints.loose(constraints.biggest)).height +
  //         layoutChild('middle', BoxConstraints.loose(constraints.biggest)).height +
  //         layoutChild('right', BoxConstraints.loose(constraints.biggest)).height +
  //         layoutChild('trailing', BoxConstraints.loose(constraints.biggest)).height;
  //     return Size(constraints.maxWidth, totalHeight);
  //   }
  //   return Size(constraints.maxWidth, currentHeight);
  // }

  @override
  Size getSize(BoxConstraints constraints) {
    return Size(constraints.maxWidth, currentHeight);
  }

  @override
  bool shouldRelayout(WidgetsLayoutsWrappedTwoColumns oldDelegate) => true;
}
