import 'dart:math';
import 'package:flutter/material.dart';

import '../../../app/content.dart';
import '../../../app/exceptions.dart';
import '../../../app/theme.dart';
import '../../../core/runtime/locator.dart';
import '../../../core/utils.dart';
import '../../../mixins/action_bar.dart';
import '../../../widgets/notify.dart';
import '../../../widgets/screens/notice.dart';
import '../markets/controller.dart';
import '../markets/model.dart';

class WatchboardScreensBubble extends StatefulWidget {
  final Widget screenNavigation;
  const WatchboardScreensBubble({super.key, required this.screenNavigation});

  @override
  State<WatchboardScreensBubble> createState() => _WatchboardScreensBubbleState();
}

class _WatchboardScreensBubbleState extends State<WatchboardScreensBubble>
    with MixinsActionBar<WatchboardScreensBubble>, SingleTickerProviderStateMixin {
  late List<MarketsModel> txs;
  List<Map<String, dynamic>> bubbles = [];

  Size _lastSize = Size.zero;
  Size _currentSize = Size.zero;

  MarketsController get _controller => locator<MarketsController>();

  @override
  void initState() {
    super.initState();
    txs = [..._controller.items];
    _processTxs();
    _controller.addListener(onMarketChange);
  }

  @override
  void dispose() {
    _controller.removeListener(onMarketChange);
    super.dispose();
  }

  @override
  Widget actionbarLeftAction() {
    return Row(mainAxisSize: MainAxisSize.min, spacing: 10, children: [widget.screenNavigation]);
  }

  @override
  Widget build(BuildContext context) {
    actionbarRegister("Crypto Bubbles");

    if (_controller.isEmpty()) {
      return WidgetsScreensNotice(
        title: "No market data available",
        btnTitle: "Download",
        btnTooltip: "Retrieve latest market data",
        btnEvaluator: (s) {
          _controller.isFetching ? s.progress() : s.action();
        },
        btnCallback: () async {
          try {
            await _controller.refreshRates();
            if (_controller.isNotEmpty()) {
              widgetsNotifySuccess("Successfully retrieved latest market data.");
            } else {
              widgetsNotifyError("Failed to retrieve market data. Please check your internet connection.");
            }
            setState(() {});
          } catch (e) {
            // This is pre IPC. Need new way!.
            if (e is NetworkingException) {
              widgetsNotifyError(e.userMessage);
            }
          }
        },
      );
    }

    return AppContent(
      boxConstraints: const BoxConstraints(maxWidth: 1600),
      padding: const EdgeInsets.all(16),
      spacing: 10,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            _currentSize = Size(constraints.maxWidth, constraints.maxHeight);

            if (_lastSize != _currentSize) {
              _generateBubble(_currentSize, _lastSize);
              _lastSize = _currentSize;
            }

            return Stack(
              children: bubbles.map((item) {
                final percent1h = item['_percentage'] as double;

                final double bx = item['x'] as double;
                final double by = item['y'] as double;
                final double bradius = item['radius'] as double;

                final double diameter = bradius * 2;
                final double left = bx - bradius;
                final double top = by - bradius;

                final double fontSizeSymbol = (bradius * 0.36).clamp(8.0, 50.0);
                final double fontSizePercent = (bradius * 0.28).clamp(9.0, 16.0);
                final bool showPercentage = bradius > 30.0;

                return Positioned(
                  left: left,
                  top: top,
                  width: diameter,
                  height: diameter,
                  child: Container(
                    decoration: BoxDecoration(
                      color: percent1h >= 0 ? AppTheme.green : AppTheme.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.background, width: 3.0),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 2,
                          children: [
                            Text(
                              item['symbol'] ?? '',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(color: AppTheme.text, fontSize: fontSizeSymbol, fontWeight: FontWeight.w600, height: 1),
                            ),
                            if (showPercentage)
                              Text(
                                "${percent1h >= 0 ? '+' : ''}${item['percentage']}%",
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: TextStyle(color: AppTheme.text, fontSize: fontSizePercent, fontWeight: FontWeight.w400),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  void _generateBubble(Size currentSize, Size oldSize) {
    if (txs.isEmpty || currentSize == Size.zero) return;

    final dataList = _generateItems();
    if (dataList.isEmpty) return;

    double maxRadius = 150.0;
    double minRadius = 24.0;
    double bubbleMargin = 12.0;
    int maxAllowedBubbles = 100;

    if (currentSize.width < 1200) {
      maxRadius = 110.0;
      minRadius = 20.0;
      bubbleMargin = 8.0;
      maxAllowedBubbles = 50;
    }

    if (currentSize.width < 800) {
      maxRadius = 90.0;
      minRadius = 20.0;
      bubbleMargin = 8.0;
      maxAllowedBubbles = 40;
    }

    if (currentSize.width < 560) {
      maxRadius = 65.0;
      minRadius = 16.0;
      bubbleMargin = 6.0;
      maxAllowedBubbles = 25;
    }

    if (maxRadius > currentSize.width) maxRadius = currentSize.width / 2;
    if (maxRadius > currentSize.height) maxRadius = currentSize.height / 2;

    dataList.sort((a, b) => (b['_percentage'] as double).abs().compareTo((a['_percentage'] as double).abs()));
    final activeItems = dataList.take(maxAllowedBubbles).toList();

    final List<Map<String, dynamic>> nextBubbles = [];
    final Map<String, Map<String, dynamic>> existingMap = {for (var b in bubbles) b['uuid'].toString(): b};

    double scaleX = (oldSize != Size.zero && oldSize.width > 0) ? currentSize.width / oldSize.width : 1.0;
    double scaleY = (oldSize != Size.zero && oldSize.height > 0) ? currentSize.height / oldSize.height : 1.0;

    double angle = 0.0;
    final double goldenRatio = (1 + sqrt(5)) / 2;

    for (int i = 0; i < activeItems.length; i++) {
      final item = activeItems[i];
      final String uuid = item['uuid'].toString();

      double targetRadius;
      if (i == 0) {
        targetRadius = maxRadius;
      } else if (i == 1) {
        targetRadius = maxRadius * 0.90;
      } else if (i == 2) {
        targetRadius = maxRadius * 0.80;
      } else if (i == 3) {
        targetRadius = maxRadius * 0.73;
      } else if (i >= 4 && i <= 9) {
        targetRadius = maxRadius * (0.66 - ((i - 4) * 0.03));
      } else if (i >= 10 && i <= 24) {
        targetRadius = maxRadius * (0.46 - ((i - 10) * 0.015));
      } else {
        targetRadius = minRadius;
      }

      targetRadius = targetRadius.clamp(minRadius, maxRadius);
      final double doubleRadius = targetRadius.toDouble();

      if (existingMap.containsKey(uuid)) {
        final oldMap = existingMap[uuid]!;
        oldMap['percentage'] = item['percentage'];
        oldMap['_percentage'] = item['_percentage'];
        oldMap['radius'] = doubleRadius;

        oldMap['x'] = (oldMap['x'] as double) * scaleX;
        oldMap['y'] = (oldMap['y'] as double) * scaleY;

        nextBubbles.add(oldMap);
      } else {
        double rDist = sqrt(i) * (maxRadius * 0.6);
        angle += goldenRatio * 2 * pi;

        double startX = (currentSize.width / 2) + cos(angle) * rDist;
        double startY = (currentSize.height / 2) + sin(angle) * rDist;

        final double minX = doubleRadius;
        final double maxX = (currentSize.width - doubleRadius).clamp(minX, currentSize.width);
        final double minY = doubleRadius;
        final double maxY = (currentSize.height - doubleRadius).clamp(minY, currentSize.height);

        item['radius'] = doubleRadius;
        item['x'] = startX.clamp(minX, maxX);
        item['y'] = startY.clamp(minY, maxY);

        nextBubbles.add(item);
      }
    }

    const double gravityForce = 0.35;
    const int relaxationIterations = 90;
    final double centerX = currentSize.width / 2;
    final double centerY = currentSize.height / 2;

    for (int pass = 0; pass < relaxationIterations; pass++) {
      for (var b in nextBubbles) {
        final double bX = b['x'] as double;
        final double bY = b['y'] as double;
        final double bRadius = b['radius'] as double;

        double dx = centerX - bX;
        double dy = centerY - bY;
        double dist = sqrt(dx * dx + dy * dy);

        if (dist > 1.0) {
          b['x'] = bX + (dx / dist) * gravityForce;
          b['y'] = bY + (dy / dist) * gravityForce;
        }

        if ((b['x'] as double) - bRadius < 0) b['x'] = bRadius;
        if ((b['x'] as double) + bRadius > currentSize.width) b['x'] = currentSize.width - bRadius;
        if ((b['y'] as double) - bRadius < 0) b['y'] = bRadius;
        if ((b['y'] as double) + bRadius > currentSize.height) b['y'] = currentSize.height - bRadius;
      }

      for (int i = 0; i < nextBubbles.length; i++) {
        for (int j = i + 1; j < nextBubbles.length; j++) {
          final b1 = nextBubbles[i];
          final b2 = nextBubbles[j];

          final double b1X = b1['x'] as double;
          final double b1Y = b1['y'] as double;
          final double b1R = b1['radius'] as double;

          final double b2X = b2['x'] as double;
          final double b2Y = b2['y'] as double;
          final double b2R = b2['radius'] as double;

          double dx = b2X - b1X;
          double dy = b2Y - b1Y;
          double distance = sqrt(dx * dx + dy * dy);
          double minDist = b1R + b2R + bubbleMargin;

          if (distance < minDist) {
            double overlap = minDist - distance;
            double nx = distance == 0 ? 1.0 : dx / distance;
            double ny = distance == 0 ? 0.0 : dy / distance;

            b1['x'] = b1X - nx * overlap * 0.5;
            b1['y'] = b1Y - ny * overlap * 0.5;
            b2['x'] = b2X + nx * overlap * 0.5;
            b2['y'] = b2Y + ny * overlap * 0.5;
          }
        }
      }
    }

    bubbles = nextBubbles;
  }

  List<Map<String, dynamic>> _generateItems() {
    final items = <Map<String, dynamic>>[];

    for (final m in txs) {
      items.add({
        'uuid': m.tid,
        'symbol': m.symbol.toString().toUpperCase(),
        'percentage': Utils.formatSmartDouble(m.percent1h ?? 0.0, maxDecimals: 2, smartDecimal: false),
        '_percentage': m.percent1h ?? 0.0,
      });
    }
    return items;
  }

  void onMarketChange() {
    txs = [..._controller.items];
    _processTxs();
    _generateBubble(_currentSize, _lastSize);
    setState(() {});
  }

  void _processTxs() {
    final stablecoins = {'usdt', 'usdc', 'dai', 'fdusd', 'usde', 'tusd', 'busd', 'pyusd', 'usdd', 'frax', 'usdg'};

    final volatileCoins = _controller.items.where((m) {
      final symbol = m.symbol.toLowerCase().trim();
      return !stablecoins.contains(symbol);
    }).toList();

    volatileCoins.sort((a, b) => a.rank.compareTo(b.rank));

    txs = volatileCoins.take(100).toList();
  }
}
