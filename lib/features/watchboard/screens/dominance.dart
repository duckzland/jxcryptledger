import 'package:flutter/material.dart';

import '../../../../app/content.dart';
import '../../../../core/runtime/locator.dart';
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
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12, top: 12),
      spacing: 10,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const double baseGap = 10.0;
            const double rowHeight = 36.0;

            return ListView.builder(
              controller: scrollUtil.controller,
              padding: EdgeInsets.zero,
              itemExtent: rowHeight + baseGap,
              itemCount: bars.length,
              itemBuilder: (context, index) {
                final item = bars[index];

                final double percent1h = item['_percent1h'] as double;
                final double rawDominance = item['_dominance'] as double;
                final double progressFraction = (rawDominance / 100.0) + 0.01;

                return Padding(
                  padding: EdgeInsets.only(bottom: baseGap, right: 8),
                  child: Row(
                    spacing: 16,
                    children: [
                      SizedBox(
                        width: 80.0,
                        child: Text(
                          item['symbol'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          textAlign: TextAlign.right,
                          style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),

                      Expanded(
                        child: Container(
                          height: rowHeight,
                          decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: AppTheme.borderRadius),
                          child: ClipRRect(
                            borderRadius: AppTheme.borderRadius,
                            child: LinearProgressIndicator(
                              value: progressFraction,
                              valueColor: AlwaysStoppedAnimation<Color>(percent1h >= 0 ? AppTheme.green : AppTheme.red),
                              backgroundColor: AppTheme.inputBg,
                              borderRadius: AppTheme.borderRadius,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(
                        width: 40.0,
                        child: Text(
                          item['dominance'] ?? '',
                          maxLines: 1,
                          textAlign: TextAlign.left,
                          style: TextStyle(color: AppTheme.text, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
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
