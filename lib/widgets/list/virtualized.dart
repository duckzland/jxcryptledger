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
  final ValueNotifier<(int, int, int)> _visibleRange = ValueNotifier((-1, -1, 0));
  int _buildGen = 0;

  VoidCallback? _scrollListener;
  ViewportOffset? _attachedOffset;

  List<double> _tops = const [];
  List<double> _heights = const [];
  double _runningTop = 0.0;

  @override
  void dispose() {
    if (_scrollListener != null && _attachedOffset != null) {
      _attachedOffset!.removeListener(_scrollListener!);
    }
    _visibleRange.dispose();
    super.dispose();
  }

  void _computeLayout(double crossAxisExtent) {
    final count = widget.itemCount;
    final tops = List<double>.filled(count, 0.0);
    final heights = List<double>.filled(count, 0.0);
    double running = 0.0;

    for (int i = 0; i < count; i++) {
      final h = widget.itemHeightBuilder(i, crossAxisExtent);
      tops[i] = running;
      heights[i] = h;
      running += h + widget.separatorHeight;
    }

    _tops = tops;
    _heights = heights;
    _runningTop = running;
  }

  int _findFirstVisibleIndex(double minVisible) {
    int low = 0;
    int high = _tops.length - 1;
    int result = _tops.length;

    while (low <= high) {
      final mid = (low + high) >> 1;
      if (_tops[mid] + _heights[mid] >= minVisible) {
        result = mid;
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }
    return result;
  }

  (int, int) _computeRange(double scrollPixels, double viewportHeight) {
    if (_tops.isEmpty) return (-1, -1);
    final start = _findFirstVisibleIndex(scrollPixels);
    int end = start - 1;
    for (int i = start; i < _tops.length; i++) {
      if (_tops[i] > scrollPixels + viewportHeight) break;
      end = i;
    }
    return (start, end);
  }

  @override
  Widget build(BuildContext context) {
    _buildGen++;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisExtent = constraints.maxWidth;
        final viewportHeight = constraints.maxHeight;

        _computeLayout(crossAxisExtent);
        final maxScrollExtent = (_runningTop - viewportHeight).clamp(0.0, double.infinity);

        return Scrollbar(
          controller: widget.controller,
          child: Scrollable(
            controller: widget.controller,
            axisDirection: AxisDirection.down,
            viewportBuilder: (context, ViewportOffset offset) {
              offset.applyViewportDimension(viewportHeight);
              offset.applyContentDimensions(0.0, maxScrollExtent);

              if (offset.hasPixels && offset.pixels > maxScrollExtent) {
                offset.correctBy(maxScrollExtent - offset.pixels);
              }

              final currentPixels = offset.hasPixels ? offset.pixels : 0.0;
              final initial = _computeRange(currentPixels, viewportHeight);
              _visibleRange.value = (initial.$1, initial.$2, _buildGen);

              if (_scrollListener != null && _attachedOffset != null) {
                _attachedOffset!.removeListener(_scrollListener!);
              }
              _attachedOffset = offset;
              _scrollListener = () {
                final next = _computeRange(offset.pixels, viewportHeight);
                _visibleRange.value = (next.$1, next.$2, _buildGen);
              };
              offset.addListener(_scrollListener!);

              return ClipRect(
                child: SizedBox(
                  width: crossAxisExtent,
                  height: viewportHeight,
                  child: ValueListenableBuilder<(int, int, int)>(
                    valueListenable: _visibleRange,
                    builder: (context, range, _) {
                      final (start, end, _) = range;
                      if (start == -1 || end < start) {
                        return const SizedBox.shrink();
                      }

                      final children = <Widget>[];
                      for (int i = start; i <= end; i++) {
                        final card = RepaintBoundary(child: widget.itemBuilder(context, i, _tops[i], _heights[i]));

                        children.add(
                          ListenableBuilder(
                            listenable: offset,
                            child: card,
                            builder: (context, builtCard) {
                              final scrollPx = offset.hasPixels ? offset.pixels : 0.0;
                              return Positioned(
                                top: _tops[i] - scrollPx,
                                left: 0,
                                right: 0,
                                height: _heights[i] + widget.separatorHeight,
                                child: builtCard!,
                              );
                            },
                          ),
                        );
                      }

                      return Stack(children: children);
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
