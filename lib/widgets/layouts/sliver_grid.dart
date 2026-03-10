import 'package:flutter/rendering.dart';

class SliverGridDelegateWithMinWidth extends SliverGridDelegate {
  final double minCrossAxisExtent;
  final double itemHeight;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double horizontalPadding; // extra padding to add

  const SliverGridDelegateWithMinWidth({
    required this.minCrossAxisExtent,
    required this.itemHeight,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
    this.horizontalPadding = 0,
  });

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    // include padding in the minimum width calculation
    final effectiveMinWidth = minCrossAxisExtent + horizontalPadding;

    final crossAxisCount = (constraints.crossAxisExtent / effectiveMinWidth).floor().clamp(1, double.infinity).toInt();

    final usableCrossAxisExtent = constraints.crossAxisExtent - (crossAxisCount - 1) * crossAxisSpacing;
    final childCrossAxisExtent = usableCrossAxisExtent / crossAxisCount;

    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: itemHeight + mainAxisSpacing,
      crossAxisStride: childCrossAxisExtent + crossAxisSpacing,
      childMainAxisExtent: itemHeight, // locked height
      childCrossAxisExtent: childCrossAxisExtent, // expands width
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(covariant SliverGridDelegateWithMinWidth oldDelegate) {
    return oldDelegate.minCrossAxisExtent != minCrossAxisExtent ||
        oldDelegate.itemHeight != itemHeight ||
        oldDelegate.mainAxisSpacing != mainAxisSpacing ||
        oldDelegate.crossAxisSpacing != crossAxisSpacing ||
        oldDelegate.horizontalPadding != horizontalPadding;
  }
}
