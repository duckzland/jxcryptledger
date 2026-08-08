import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../../app/content.dart';
import '../../../core/runtime/locators/client.dart';
import '../../../../mixins/action_bar.dart';
import '../../../app/theme.dart';
import '../../../core/scrollto.dart';
import '../../../mixins/state.dart';
import '../../../widgets/separator.dart';
import '../markets/controller.dart';
import '../markets/mixins/filterable.dart';
import '../markets/model.dart';
import '../markets/widgets/notice.dart';

class WatchboardScreensDominance extends StatefulWidget {
  final Widget screenNavigation;
  const WatchboardScreensDominance({super.key, required this.screenNavigation});

  @override
  State<WatchboardScreensDominance> createState() => _WatchboardScreensDominanceState();
}

class _WatchboardScreensDominanceState extends State<WatchboardScreensDominance>
    with MixinsState, MixinsActionBar<WatchboardScreensDominance>, WatchboardMarketsMixinsFilterable<WatchboardScreensDominance> {
  late List<MarketsModel> txs;

  MarketsController get _controller => locator<MarketsController>();

  final scrollUtil = ScrollTo('px-group-offset-dominance');

  @override
  String get marketFilterableKey => "px-group-dominance";

  @override
  void initState() {
    super.initState();
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
  void marketFilterableOnPriceFiltering(int value) => onMarketChange();

  @override
  void marketFilterableOnPercentFiltering(int value) => onMarketChange();

  @override
  Widget actionbarLeftAction() {
    List<Widget> navigation = [widget.screenNavigation];
    if (_controller.isNotEmpty()) {
      navigation = [widget.screenNavigation, const WidgetsSeparator(), marketFilterableRankFilters()];
    }
    return Row(mainAxisSize: MainAxisSize.min, spacing: 10, children: navigation);
  }

  @override
  Widget build(BuildContext context) {
    actionbarRegister("Crypto Dominance");

    if (_controller.isEmpty()) {
      return WatchboardsMarketsWidgetsNotice(callback: () => setState(() {}));
    }

    return AppContent(
      boxConstraints: BoxConstraints(maxWidth: 1600),
      padding: EdgeInsets.only(left: 16, right: 16, bottom: 12, top: 12),
      spacing: 10,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final double baseGap = 10.0;
            final double barHeight = 36.0;

            return ListView.builder(
              controller: scrollUtil.controller,
              padding: EdgeInsets.zero,
              itemExtent: barHeight + baseGap,
              itemCount: txs.length,
              itemBuilder: (context, index) {
                final tx = txs[index];

                final Decimal percent1h = tx.percent1h ?? Decimal.zero;
                final Decimal rawDominance = tx.dominance ?? Decimal.zero;
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
                          valueColor: AlwaysStoppedAnimation<Color>(percent1h >= Decimal.zero ? AppTheme.green : AppTheme.red),
                          backgroundColor: AppTheme.inputBg,
                          borderRadius: AppTheme.borderRadius,
                        ),
                      ),

                      SizedBox(
                        width: 40.0,
                        child: Text(
                          tx.dominanceText,
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
    setState(() {
      _processTxs();
    });
  }

  void _processTxs() {
    txs = [..._controller.items];
    txs = txs.where((m) => !m.isStableCoin).toList();
    txs = marketFilterableFilter(txs);
    txs.sort((a, b) => a.rank.compareTo(b.rank));
  }
}
