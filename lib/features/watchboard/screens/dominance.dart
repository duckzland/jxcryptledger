import 'dart:math';
import 'package:flutter/material.dart';

import '../../../../app/content.dart';
import '../../../../core/runtime/locator.dart';
import '../../../../core/utils.dart';
import '../../../../mixins/action_bar.dart';
import '../../../app/theme.dart';
import '../../../core/scrollto.dart';
import '../markets/controller.dart';
import '../markets/model.dart';

class WatchboardScreensDominance extends StatefulWidget {
  final Widget screenNavigation;
  const WatchboardScreensDominance({super.key, required this.screenNavigation});

  @override
  State<WatchboardScreensDominance> createState() => _WatchboardScreensDominanceState();
}

class _WatchboardScreensDominanceState extends State<WatchboardScreensDominance> with MixinsActionBar<WatchboardScreensDominance> {
  late List<MarketsModel> txs;

  List<Map<String, dynamic>> grids = [];

  MarketsController get _controller => locator<MarketsController>();

  final scrollUtil = ScrollTo('px-offset-dominance');

  @override
  void initState() {
    super.initState();
    txs = [..._controller.items];
    _processTxs();
    _controller.addListener(onMarketChange);
  }

  @override
  void dispose() {
    scrollUtil.dispose();
    _controller.removeListener(onMarketChange);
    super.dispose();
  }

  @override
  Widget actionbarLeftAction() {
    return Row(mainAxisSize: MainAxisSize.min, spacing: 10, children: [widget.screenNavigation]);
  }

  @override
  Widget build(BuildContext context) {
    actionbarRegister("Crypto Dominance");

    return AppContent(
      boxConstraints: const BoxConstraints(maxWidth: 1600),
      padding: const EdgeInsets.all(16),
      spacing: 10,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            int cols = 24;
            const double minSquarePx = 30.0;
            const double baseGap = 10.0;

            if (constraints.maxWidth / 24 < minSquarePx) {
              cols = 12;
              if (constraints.maxWidth / 12 < minSquarePx) {
                cols = 6;
              }
            }

            final double squareW = constraints.maxWidth / cols;
            final double squareH = squareW;

            _generateMasonryGrid(cols, squareW, squareH, baseGap);

            double totalCalculatedHeight = 0.0;
            for (final item in grids) {
              final double itemBottom = (item['layoutY'] as double) + (item['layoutH'] as double) + baseGap;
              if (itemBottom > totalCalculatedHeight) {
                totalCalculatedHeight = itemBottom;
              }
            }

            return SingleChildScrollView(
              controller: scrollUtil.controller,
              child: SizedBox(
                height: totalCalculatedHeight,
                width: constraints.maxWidth,
                child: Stack(
                  children: grids.map((item) {
                    final double left = item['layoutX'] as double;
                    final double top = item['layoutY'] as double;
                    final double width = item['layoutW'] as double;
                    final double height = item['layoutH'] as double;

                    final double minDimension = min(width, height);
                    final String symbolText = (item['symbol'] ?? '').toString().toUpperCase();
                    final String dominanceText = item['dominance'];

                    final int symbolLength = symbolText.isNotEmpty ? symbolText.length : 3;
                    final int percentLength = dominanceText.isNotEmpty ? dominanceText.length : 5;

                    final double fontSizeSymbol = ((minDimension * 0.95) / symbolLength).clamp(14.0, 46.0);
                    final double fontSizePercent = ((minDimension * 1.0) / percentLength).clamp(12.0, 16.0);
                    final bool showPercentage = minDimension > 45.0;

                    return Positioned(
                      left: left,
                      top: top,
                      width: width,
                      height: height,
                      child: Container(
                        decoration: BoxDecoration(
                          color: item['_percent1h'] >= 0 ? AppTheme.green : AppTheme.red,
                          borderRadius: AppTheme.borderRadius,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 2,
                          children: [
                            Text(
                              symbolText,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(color: AppTheme.text, fontSize: fontSizeSymbol, fontWeight: FontWeight.w600, height: 1),
                            ),
                            if (showPercentage) ...[
                              Text(
                                dominanceText,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: TextStyle(color: AppTheme.text, fontSize: fontSizePercent, fontWeight: FontWeight.w400),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _generateMasonryGrid(int cols, double squareW, double squareH, double gap) {
    final dataList = _generateItems();
    if (dataList.isEmpty) return;

    const int maxRowsBuffer = 300;
    final List<List<bool>> occupied = List.generate(maxRowsBuffer, (_) => List.filled(cols, false));

    final int itemsToRender = dataList.length;

    for (int i = 0; i < itemsToRender; i++) {
      final item = dataList[i];

      int spanW = 2;
      int spanH = 1;

      if (i == 0) {
        spanW = cols >= 24 ? 10 : (cols >= 12 ? 8 : 6);
        spanH = 6;
      } else if (i == 1) {
        spanW = cols >= 24 ? 8 : (cols >= 12 ? 6 : 4);
        spanH = 4;
      } else if (i >= 2 && i <= 16) {
        spanW = cols >= 24 ? 6 : 4;
        spanH = 3;
      } else if (i >= 17 && i <= 69) {
        spanW = 4;
        spanH = 2;
      } else {
        spanW = 2;
        spanH = 1;
      }

      int targetRow = -1;
      int targetCol = -1;
      bool spaceFound = false;

      for (int r = 0; r < maxRowsBuffer - spanH; r++) {
        for (int c = 0; c < cols - spanW + 1; c++) {
          if (!occupied[r][c]) {
            bool fits = true;
            for (int h = 0; h < spanH; h++) {
              for (int w = 0; w < spanW; w++) {
                if (occupied[r + h][c + w]) {
                  fits = false;
                  break;
                }
              }
              if (!fits) break;
            }

            if (fits) {
              targetRow = r;
              targetCol = c;
              spaceFound = true;
              break;
            }
          }
        }
        if (spaceFound) break;
      }

      if (!spaceFound) {
        spanW = 2;
        spanH = 2;
        for (int r = 0; r < maxRowsBuffer - 2; r++) {
          for (int c = 0; c < cols - 1; c++) {
            if (!occupied[r][c] && !occupied[r + 1][c] && !occupied[r][c + 1] && !occupied[r + 1][c + 1]) {
              targetRow = r;
              targetCol = c;
              spaceFound = true;
              break;
            }
          }
          if (spaceFound) break;
        }
      }

      if (!spaceFound) continue;

      for (int h = 0; h < spanH; h++) {
        for (int w = 0; w < spanW; w++) {
          occupied[targetRow + h][targetCol + w] = true;
        }
      }

      item['layoutX'] = targetCol * squareW;
      item['layoutY'] = targetRow * squareH;
      item['layoutW'] = (spanW * squareW) - gap;
      item['layoutH'] = (spanH * squareH) - gap;
    }

    grids = dataList.where((item) => item.containsKey('layoutX')).toList();
  }

  List<Map<String, dynamic>> _generateItems() {
    final items = <Map<String, dynamic>>[];

    for (final m in txs) {
      items.add({
        'uuid': m.tid,
        'symbol': m.symbol,
        'dominance': Utils.formatSmartDouble(m.dominance ?? 0.0, maxDecimals: 2, smartDecimal: false),
        '_dominance': m.dominance ?? 0.0,
        '_percent1h': m.percent1h ?? 0.0,
      });
    }

    items.sort((a, b) => (b['_dominance'] as double).compareTo(a['_dominance'] as double));
    return items;
  }

  void onMarketChange() {
    txs = [..._controller.items];
    _processTxs();
    setState(() {});
  }

  void _processTxs() {
    final stablecoins = {'usdt', 'usdc', 'dai', 'fdusd', 'usde', 'tusd', 'busd', 'pyusd', 'usdd', 'frax'};

    final volatileCoins = _controller.items.where((m) {
      final symbol = m.symbol.toLowerCase().trim();
      return !stablecoins.contains(symbol);
    }).toList();

    volatileCoins.sort((a, b) => a.rank.compareTo(b.rank));

    txs = volatileCoins.take(100).toList();
  }
}
