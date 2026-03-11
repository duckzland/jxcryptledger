import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/rates/controller.dart';
import '../core/locator.dart';
import '../features/cryptos/controller.dart';
import '../widgets/button.dart';
import '../widgets/notify.dart';
import 'exceptions.dart';
import 'theme.dart';

class AppLayout extends StatefulWidget {
  static void Function(String)? setTitle;

  final String title;
  final Widget child;

  const AppLayout({super.key, required this.title, required this.child});

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  late String _title = widget.title;
  late CryptosController _cryptosController;
  late RatesController _ratesController;

  void _setTitle(String newTitle) {
    setState(() => _title = newTitle);
  }

  bool _isFetchingRates = false;
  bool _isFetchingCryptos = false;

  @override
  void initState() {
    super.initState();
    AppLayout.setTitle = _setTitle;

    _cryptosController = locator<CryptosController>();
    _ratesController = locator<RatesController>();

    _ratesController.addListener(_onControllerChanged);
    _cryptosController.addListener(_onControllerChanged);

    _isFetchingRates = _ratesController.isFetching;
    _isFetchingCryptos = _cryptosController.isFetching;
  }

  @override
  void dispose() {
    super.dispose();
    _ratesController.removeListener(_onControllerChanged);
    _cryptosController.removeListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {
        _isFetchingRates = _ratesController.isFetching;
        _isFetchingCryptos = _cryptosController.isFetching;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([locator<CryptosController>(), locator<RatesController>()]),
      builder: (context, _) {
        final hasRates = _ratesController.hasRates;
        final location = GoRouterState.of(context).uri.toString();

        // logln("message: Building AppLayout for location: $location");

        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppTheme.columnHeaderBg,
            centerTitle: true,
            leadingWidth: 210,
            leading: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Center(
                child: Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    WidgetsButton(
                      icon: Icons.account_balance_wallet,
                      padding: const EdgeInsets.all(8),
                      iconSize: 20,
                      minimumSize: const Size(40, 40),
                      tooltip: "Manage Transactions",
                      evaluator: (s) {
                        if (location == "/transactions" || location == "/") {
                          s.active();
                        } else {
                          s.normal();
                        }
                      },
                      onPressed: (s) {
                        context.go("/transactions");
                      },
                    ),

                    WidgetsButton(
                      icon: Icons.candlestick_chart,
                      padding: const EdgeInsets.all(8),
                      iconSize: 20,
                      minimumSize: const Size(40, 40),
                      tooltip: "Display Watchboard",
                      evaluator: (s) {
                        if (location == "/watchboard") {
                          s.active();
                        } else {
                          s.normal();
                        }
                      },
                      onPressed: (s) {
                        context.go("/watchboard");
                      },
                    ),

                    WidgetsButton(
                      icon: Icons.notification_add,
                      padding: const EdgeInsets.all(8),
                      iconSize: 20,
                      minimumSize: const Size(40, 40),
                      tooltip: "Manage Rate Watchers",
                      evaluator: (s) {
                        if (location == "/watchers") {
                          s.active();
                        } else {
                          s.normal();
                        }
                      },
                      onPressed: (s) {
                        context.go("/watchers");
                      },
                    ),

                    WidgetsButton(
                      icon: Icons.handyman,
                      padding: const EdgeInsets.all(8),
                      iconSize: 20,
                      minimumSize: const Size(40, 40),
                      tooltip: "Use Crypto Tools",
                      evaluator: (s) {
                        if (location == "/tools") {
                          s.active();
                        } else {
                          s.normal();
                        }
                      },
                      onPressed: (s) {
                        context.go("/tools");
                      },
                    ),

                    WidgetsButton(
                      icon: Icons.settings,
                      padding: const EdgeInsets.all(8),
                      iconSize: 20,
                      minimumSize: const Size(40, 40),
                      tooltip: "Settings",
                      evaluator: (s) {
                        if (location == "/settings") {
                          s.active();
                        } else {
                          s.normal();
                        }
                      },
                      onPressed: (s) {
                        context.go("/settings");
                      },
                    ),
                  ],
                ),
              ),
            ),
            title: Text(_title),
            actions: [
              Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  WidgetsButton(
                    icon: Icons.refresh,
                    padding: const EdgeInsets.all(8),
                    iconSize: 20,
                    minimumSize: const Size(40, 40),
                    tooltip: "Refresh Cryptos",
                    evaluator: (s) {
                      _isFetchingCryptos ? s.progress() : s.reset();
                    },
                    onPressed: (s) async {
                      s.progress();
                      try {
                        await _cryptosController.fetch();
                        widgetsNotifySuccess("Cryptocurrency list successfully retrieved.");
                      } catch (e) {
                        if (e is NetworkingException) {
                          widgetsNotifyError(e.userMessage);
                        }
                      } finally {
                        s.reset();
                      }
                    },
                  ),

                  if (hasRates)
                    WidgetsButton(
                      icon: Icons.autorenew,
                      padding: const EdgeInsets.all(8),
                      iconSize: 20,
                      minimumSize: const Size(40, 40),
                      tooltip: "Refresh Rates",
                      evaluator: (s) {
                        _isFetchingRates ? s.progress() : s.reset();
                      },
                      onPressed: (s) async {
                        s.progress();
                        try {
                          await _ratesController.refreshRates();
                          widgetsNotifySuccess("Refreshed rates from exchange.");
                        } catch (e) {
                          if (e is NetworkingException) {
                            widgetsNotifyError(e.userMessage);
                          }
                        } finally {
                          s.reset();
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), child: widget.child),
        );
      },
    );
  }
}
