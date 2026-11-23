import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class WidgetsListVirtualized extends StatefulWidget {
  final ScrollController controller;
  final int itemCount;
  final double separatorHeight;
  final double Function(int index, double crossAxisExtent) itemHeightBuilder;
  final Widget Function(BuildContext context, int index, double itemTop, double itemHeight) itemBuilder;

  const WidgetsListVirtualized({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.itemHeightBuilder,
    required this.itemBuilder,
    this.separatorHeight = 0.0,
  });

  @override
  State<WidgetsListVirtualized> createState() => _WidgetsListVirtualizedState();
}

class _WidgetsListVirtualizedState extends State<WidgetsListVirtualized> {
  List<double> _tops = const [];
  List<double> _heights = const [];
  double _totalHeight = 0.0;
  String? _cachedKey;

  @override
  void didUpdateWidget(covariant WidgetsListVirtualized oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount ||
        oldWidget.separatorHeight != widget.separatorHeight ||
        oldWidget.itemHeightBuilder != widget.itemHeightBuilder) {
      _cachedKey = null;
      _tops = const [];
      _heights = const [];
      _totalHeight = 0.0;
    }
  }

  void _ensureLayout(double width, double height) {
    final ck = "$width-$height";

    if (_cachedKey == ck) return;

    _cachedKey = ck;
    _totalHeight = 0.0;

    _tops = List<double>.filled(widget.itemCount, 0.0);
    _heights = List<double>.filled(widget.itemCount, 0.0);

    for (int i = 0; i < widget.itemCount; i++) {
      final h = widget.itemHeightBuilder(i, width);
      _tops[i] = _totalHeight;
      _heights[i] = h;
      _totalHeight += h + widget.separatorHeight;
    }
  }

  int _firstVisibleIndex(double scrollPx) {
    int low = 0;
    int high = _tops.length - 1;
    int result = _tops.length;

    while (low <= high) {
      final mid = (low + high) >> 1;
      if (_tops[mid] + _heights[mid] >= scrollPx) {
        result = mid;
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        _ensureLayout(width, height);

        final maxScroll = (_totalHeight - height).clamp(0.0, double.infinity);

        return Scrollable(
          controller: widget.controller,
          axisDirection: AxisDirection.down,
          viewportBuilder: (context, ViewportOffset offset) {
            offset.applyViewportDimension(height);
            offset.applyContentDimensions(0.0, maxScroll);

            if (offset.hasPixels && offset.pixels > maxScroll) {
              offset.correctBy(maxScroll - offset.pixels);
            }

            return RepaintBoundary(
              child: SizedBox(
                width: width,
                height: height,
                child: ClipRect(
                  child: ListenableBuilder(
                    listenable: offset,
                    builder: (context, _) {
                      if (_tops.isEmpty) return const SizedBox.shrink();

                      final scrollPx = offset.hasPixels ? offset.pixels : 0.0;
                      final start = _firstVisibleIndex(scrollPx);
                      final children = <Widget>[];

                      for (int i = start; i < _tops.length && _tops[i] <= scrollPx + height; i++) {
                        children.add(
                          Positioned(
                            key: ValueKey(i),
                            top: _tops[i] - scrollPx,
                            left: 0,
                            right: 0,
                            height: _heights[i] + widget.separatorHeight,
                            child: RepaintBoundary(child: widget.itemBuilder(context, i, _tops[i], _heights[i])),
                          ),
                        );
                      }

                      return Stack(children: children);
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
