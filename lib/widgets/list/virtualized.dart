import 'package:flutter/material.dart';

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
  double _width = 0.0;
  double _height = 0.0;
  List<double> _tops = const [];
  List<double> _heights = const [];
  double _totalHeight = 0.0;
  String? _cachedKey;

  @override
  void didUpdateWidget(covariant WidgetsListVirtualized oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cachedKey = null;
    _ensureLayout(_width, _height);

    // Fix update too fast showing blank screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _cachedKey = null;
        _ensureLayout(_width, _height);
      });
    });
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
        _width = constraints.maxWidth;
        _height = constraints.maxHeight;

        _ensureLayout(_width, _height);

        if (widget.controller.hasClients) {
          final offset = widget.controller.position;
          final maxHeight = _totalHeight > _height ? (_totalHeight - _height).clamp(0.0, double.infinity) : _height;

          offset.applyViewportDimension(_height);
          offset.applyContentDimensions(0.0, maxHeight);

          if (offset.hasPixels && offset.pixels > maxHeight) {
            offset.correctBy(maxHeight - offset.pixels);
            offset.notifyListeners();
          }
        }

        return SingleChildScrollView(
          controller: widget.controller,
          child: SizedBox(
            height: _totalHeight,
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final scrollPx = widget.controller.hasClients ? widget.controller.offset : 0.0;
                final start = _firstVisibleIndex(scrollPx);
                final children = <Widget>[];

                for (int i = start; i < _tops.length && _tops[i] <= scrollPx + _height; i++) {
                  children.add(
                    Positioned(
                      top: _tops[i],
                      left: 0,
                      right: 0,
                      height: _heights[i] + widget.separatorHeight,
                      child: widget.itemBuilder(context, i, _tops[i], _heights[i]),
                    ),
                  );
                }

                return Stack(children: children);
              },
            ),
          ),
        );
      },
    );
  }
}
