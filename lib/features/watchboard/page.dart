import 'package:flutter/material.dart';

import '../../mixins/state.dart';
import '../../widgets/buttons/action.dart';
import 'screens/board.dart';
import 'screens/bubble.dart';
import 'screens/dominance.dart';
import 'screens/market.dart';

enum WatchboardViewMode { board, market, bubble, dominance }

class WatchboardPage extends StatefulWidget {
  const WatchboardPage({super.key});

  @override
  State<WatchboardPage> createState() => _WatchboardPageState();
}

class _WatchboardPageState extends State<WatchboardPage> with MixinsState {
  WatchboardViewMode _viewMode = WatchboardViewMode.board;

  @override
  void initState() {
    super.initState();

    _viewMode = WatchboardViewMode.values.byName(states.get('px-view-mode', defaultValue: "board"));
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _registerNavigation() {
    return Wrap(
      spacing: 4,
      children: [
        WidgetsButtonsAction(
          key: const Key("view-board"),
          icon: Icons.space_dashboard,
          padding: EdgeInsets.all(8),
          iconSize: 20,
          minimumSize: const Size(40, 40),
          tooltip: "Crypto Board",
          evaluator: (s) {
            if (_viewMode == WatchboardViewMode.board) {
              s.active();
            } else {
              s.normal();
            }
          },
          onPressed: (_) {
            setState(() {
              _viewMode = WatchboardViewMode.board;
              states.set('px-view-mode', WatchboardViewMode.board.name);
            });
          },
        ),

        WidgetsButtonsAction(
          key: const Key("view-market"),
          icon: Icons.view_list,
          padding: EdgeInsets.all(8),
          iconSize: 20,
          minimumSize: const Size(40, 40),
          tooltip: "Crypto Market",
          evaluator: (s) {
            if (_viewMode == WatchboardViewMode.market) {
              s.active();
            } else {
              s.normal();
            }
          },
          onPressed: (_) {
            setState(() {
              _viewMode = WatchboardViewMode.market;
              states.set('px-view-mode', WatchboardViewMode.market.name);
            });
          },
        ),

        WidgetsButtonsAction(
          key: const Key("view-bubble"),
          icon: Icons.bubble_chart,
          padding: EdgeInsets.all(8),
          iconSize: 20,
          minimumSize: const Size(40, 40),
          tooltip: "Crypto Bubble",
          evaluator: (s) {
            if (_viewMode == WatchboardViewMode.bubble) {
              s.active();
            } else {
              s.normal();
            }
          },
          onPressed: (_) {
            setState(() {
              _viewMode = WatchboardViewMode.bubble;
              states.set('px-view-mode', WatchboardViewMode.bubble.name);
            });
          },
        ),

        WidgetsButtonsAction(
          key: const Key("view-dominance"),
          icon: Icons.leaderboard,
          padding: EdgeInsets.all(8),
          iconSize: 20,
          minimumSize: const Size(40, 40),
          tooltip: "Crypto Dominance",
          evaluator: (s) {
            if (_viewMode == WatchboardViewMode.dominance) {
              s.active();
            } else {
              s.normal();
            }
          },
          onPressed: (_) {
            setState(() {
              _viewMode = WatchboardViewMode.dominance;
              states.set('px-view-mode', WatchboardViewMode.dominance.name);
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final navHandler = _registerNavigation();

    switch (_viewMode) {
      case WatchboardViewMode.board:
        return WatchboardScreensBoard(key: const ValueKey('wb-board'), screenNavigation: navHandler);
      case WatchboardViewMode.market:
        return WatchboardScreensMarket(key: const ValueKey('wb-market'), screenNavigation: navHandler);
      case WatchboardViewMode.bubble:
        return WatchboardScreensBubble(key: const ValueKey('wb-bubble'), screenNavigation: navHandler);
      case WatchboardViewMode.dominance:
        return WatchboardScreensDominance(key: const ValueKey('wb-dominance'), screenNavigation: navHandler);
    }
  }
}
