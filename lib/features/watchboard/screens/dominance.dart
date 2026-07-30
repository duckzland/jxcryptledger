import 'package:flutter/material.dart';

import '../../../../app/content.dart';
import '../../../../core/runtime/locator.dart';
import '../../../../mixins/action_bar.dart';
import '../../../app/theme.dart';
import '../../../core/scrollto.dart';
import '../../../core/utils.dart';
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
            const double barHeight = 36.0;

            return ListView.builder(
              controller: scrollUtil.controller,
              padding: EdgeInsets.zero,
              itemExtent: barHeight + baseGap,
              itemCount: txs.length,
              itemBuilder: (context, index) {
                final tx = txs[index];

                final double percent1h = tx.percent1h ?? 0.0;
                final double rawDominance = tx.dominance ?? 0.0;
                final double progressFraction = ((rawDominance.toDouble() / 100.0) + 0.01).clamp(0.01, 1.00);

                return Padding(
                  padding: EdgeInsets.only(bottom: baseGap, right: 8),
                  child: Row(
                    spacing: 16,
                    children: [
                      SizedBox(
                        width: 80.0,
                        child: Text(
                          tx.symbol.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          textAlign: TextAlign.right,
                          style: TextStyle(color: AppTheme.text, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),

                      Expanded(
                        child: LinearProgressIndicator(
                          minHeight: barHeight,
                          value: progressFraction,
                          valueColor: AlwaysStoppedAnimation<Color>(percent1h >= 0 ? AppTheme.green : AppTheme.red),
                          backgroundColor: AppTheme.inputBg,
                          borderRadius: AppTheme.borderRadius,
                        ),
                      ),

                      SizedBox(
                        width: 40.0,
                        child: Text(
                          Utils.formatSmartDouble(tx.dominance ?? 0.0, maxDecimals: 2),
                          maxLines: 1,
                          textAlign: TextAlign.left,
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
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
