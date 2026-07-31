import 'package:flutter/material.dart';

import '../../../../app/content.dart';
import '../../../../core/runtime/locator.dart';
import '../../../../mixins/action_bar.dart';
import '../../../app/exceptions.dart';
import '../../../app/theme.dart';
import '../../../core/scrollto.dart';
import '../../../mixins/state.dart';
import '../../../widgets/notify.dart';
import '../../../widgets/screens/notice.dart';
import '../../../widgets/separator.dart';
import '../markets/controller.dart';
import '../markets/model.dart';

class WatchboardScreensDominance extends StatefulWidget {
  final Widget screenNavigation;
  const WatchboardScreensDominance({super.key, required this.screenNavigation});

  @override
  State<WatchboardScreensDominance> createState() => _WatchboardScreensDominanceState();
}

class _WatchboardScreensDominanceState extends State<WatchboardScreensDominance>
    with MixinsState, MixinsActionBar<WatchboardScreensDominance> {
  late List<MarketsModel> txs;

  MarketsController get _controller => locator<MarketsController>();

  final scrollUtil = ScrollTo('px-group-offset-dominance');

  int _filterMode = 0;

  @override
  void initState() {
    super.initState();
    _filterMode = states.get('px-group-filter-dominance', defaultValue: 0);

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
    List<Widget> navigation = [widget.screenNavigation];
    if (_controller.isNotEmpty()) {
      navigation = [
        widget.screenNavigation,
        const WidgetsSeparator(),
        DropdownMenu<int>(
          initialSelection: _filterMode,
          alignmentOffset: const Offset(0, 3),
          requestFocusOnTap: false,
          inputDecorationTheme: Theme.of(
            context,
          ).inputDecorationTheme.copyWith(isDense: true, constraints: const BoxConstraints(maxHeight: 38)),
          showTrailingIcon: false,
          dropdownMenuEntries: [
            const DropdownMenuEntry<int>(value: 0, label: "Show All"),
            const DropdownMenuEntry<int>(value: 1, label: "Top 50"),
            const DropdownMenuEntry<int>(value: 2, label: "Top 100"),
            const DropdownMenuEntry<int>(value: 3, label: "Top 200"),
          ],
          onSelected: (value) {
            if (value == null) return;
            setState(() {
              _filterMode = value;
              _processTxs();
            });
            states.set('px-group-filter-dominance', value);
          },
        ),
      ];
    }
    return Row(mainAxisSize: MainAxisSize.min, spacing: 10, children: navigation);
  }

  @override
  Widget build(BuildContext context) {
    actionbarRegister("Crypto Dominance");

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
    switch (_filterMode) {
      case 1:
        txs = txs.where((tx) => tx.rank >= 1 && tx.rank <= 50).toList();
        break;

      case 2:
        txs = txs.where((tx) => tx.rank >= 1 && tx.rank <= 100).toList();
        break;

      case 3:
        txs = txs.where((tx) => tx.rank >= 101 && tx.rank <= 200).toList();
        break;

      default:
        break;
    }

    txs.sort((a, b) => a.rank.compareTo(b.rank));
  }
}
