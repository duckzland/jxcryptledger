import 'dart:math';
import 'package:flutter/material.dart';
import 'package:jxledger/widgets/panel.dart';

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

  List<Map<String, dynamic>> bars = [];

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
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      spacing: 10,
      children: [
        WidgetsPanel(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const double baseGap = 10.0;
              const double rowHeight = 36.0;

              _generateBars(constraints.maxWidth, baseGap);

              return ListView.builder(
                controller: scrollUtil.controller,
                padding: EdgeInsets.zero,
                itemExtent: rowHeight + baseGap,
                itemCount: bars.length,
                itemBuilder: (context, index) {
                  final item = bars[index];

                  final double barWidth = item['layoutW'] as double;
                  final double percent1h = item['_percent1h'] as double;

                  return Padding(
                    padding: EdgeInsets.only(bottom: baseGap),
                    child: Row(
                      children: [
                        Container(
                          width: barWidth,
                          height: rowHeight,
                          padding: const EdgeInsets.symmetric(horizontal: baseGap),
                          decoration: BoxDecoration(
                            color: percent1h >= 0 ? AppTheme.green : AppTheme.red,
                            borderRadius: AppTheme.borderRadius,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item['symbol'] ?? '',
                                maxLines: 1,
                                style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.bold),
                              ),

                              Text(
                                item['dominance'] ?? '',
                                maxLines: 1,
                                style: TextStyle(color: AppTheme.text, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _generateBars(double maxWidth, double gap) {
    final dataList = _generateItems();
    if (dataList.isEmpty) return;

    const double rightLabelReservedSpace = 0;
    final double safeBarMaxLaneWidth = maxWidth - rightLabelReservedSpace;

    final double maxDominanceInPool = dataList.fold(
      0.01,
      (prev, current) => (current['_dominance'] as double) > prev ? (current['_dominance'] as double) : prev,
    );

    for (final item in dataList) {
      final double dominance = item['_dominance'] as double;

      double logCurrent = log(1.0 + dominance);
      double logMaxCap = log(1.0 + maxDominanceInPool);

      double dynamicScaleFactor = logCurrent / logMaxCap;

      double calculatedWidth = (dynamicScaleFactor * safeBarMaxLaneWidth);

      double minAllowedFloor = min(140.0, safeBarMaxLaneWidth);
      double finalBarWidth = max(minAllowedFloor, calculatedWidth);

      item['layoutW'] = min(finalBarWidth, safeBarMaxLaneWidth);
      item['layoutH'] = 36.0;
      item['layoutX'] = 0.0;
      item['layoutY'] = 0.0;
    }

    bars = dataList;
  }

  List<Map<String, dynamic>> _generateItems() {
    final items = <Map<String, dynamic>>[];

    for (final m in txs) {
      items.add({
        'uuid': m.tid,
        'symbol': m.symbol.toString().toUpperCase(),
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
    final stablecoins = {'usdt', 'usdc', 'dai', 'fdusd', 'usde', 'tusd', 'busd', 'pyusd', 'usdd', 'frax', 'usdg'};

    final volatileCoins = _controller.items.where((m) {
      final symbol = m.symbol.toLowerCase().trim();
      return !stablecoins.contains(symbol);
    }).toList();

    volatileCoins.sort((a, b) => a.rank.compareTo(b.rank));

    txs = volatileCoins.take(100).toList();
  }
}
