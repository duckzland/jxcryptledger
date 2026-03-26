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
  static void Function(Widget?)? setActions;
  static void Function()? refreshBar;

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

  void _setActions(Widget? actions) {
    setState(() => _actions = actions);
  }

  void _refreshBar() {
    setState(() => _barBuildId = _barBuildId + 1);
  }

  Widget? _actions;
  bool _isFetchingRates = false;
  bool _isFetchingCryptos = false;
  int _barBuildId = 1;

  @override
  void initState() {
    super.initState();
    _actions = null;

    AppLayout.setTitle = _setTitle;
    AppLayout.setActions = _setActions;
    AppLayout.refreshBar = _refreshBar;

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
        final location = GoRouterState.of(context).uri.toString();

        // logln("message: Building AppLayout for location: $location");

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final double leadingWidth = width < 800 ? 0 : 210;
            final showMenu = width < 800;

            return Scaffold(
              drawer: (showMenu) ? _buildDrawer(context) : null,
              appBar: AppBar(
                backgroundColor: AppTheme.columnHeaderBg,
                centerTitle: true,
                leadingWidth: leadingWidth,
                leading: _buildLeading(),
                title: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.of(context).size.width;
                    return SizedBox(
                      width: width,
                      child: Row(
                        spacing: 8,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          if (!showMenu) Container(width: 1, height: 24, color: AppTheme.separator),
                          _buildNavigation(location, showMenu, context),

                          Container(width: 1, height: 24, color: AppTheme.separator),

                          if (_actions != null) Expanded(key: Key("bid-$_barBuildId"), child: _actions!),
                        ],
                      ),
                    );
                  },
                ),
                actions: [if (!showMenu) _buildActions(), if (!showMenu) SizedBox(width: 16)],
              ),
              body: Padding(
                padding: EdgeInsets.only(left: 16, right: 16, top: !showMenu ? 16 : 8, bottom: 8),
                child: widget.child,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final hasRates = _ratesController.hasRates;

    return Drawer(
      child: ListView(
        children: [
          Container(
            height: 60,
            color: AppTheme.primary,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),

          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: const Text("Manage Transactions"),
            onTap: () {
              Navigator.pop(context);
              context.go("/transactions");
            },
          ),
          ListTile(
            leading: const Icon(Icons.candlestick_chart),
            title: const Text("Display Watchboard"),
            onTap: () {
              Navigator.pop(context);
              context.go("/watchboard");
            },
          ),
          ListTile(
            leading: const Icon(Icons.notification_add),
            title: const Text("Manage Rate Watchers"),
            onTap: () {
              Navigator.pop(context);
              context.go("/watchers");
            },
          ),
          ListTile(
            leading: const Icon(Icons.handyman),
            title: const Text("Use Crypto Tools"),
            onTap: () {
              Navigator.pop(context);
              context.go("/tools");
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Settings"),
            onTap: () {
              Navigator.pop(context);
              context.go("/settings");
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text("Refresh Cryptos"),
            onTap: () async {
              Navigator.pop(context);
              try {
                await _cryptosController.fetch();
                widgetsNotifySuccess("Cryptocurrency list successfully retrieved.");
              } catch (e) {
                if (e is NetworkingException) {
                  widgetsNotifyError(e.userMessage);
                }
              }
            },
          ),
          if (hasRates)
            ListTile(
              leading: const Icon(Icons.autorenew),
              title: const Text("Refresh Rates"),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await _ratesController.refreshRates();
                  widgetsNotifySuccess("Refreshed rates from exchange.");
                } catch (e) {
                  if (e is NetworkingException) {
                    widgetsNotifyError(e.userMessage);
                  }
                }
              },
            ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.close),
            title: const Text("Close Menu"),
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLeading() {
    return Padding(
      padding: EdgeInsets.only(left: 16.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(_title, style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildActions() {
    final hasRates = _ratesController.hasRates;
    return Row(
      spacing: 8,
      children: [
        Container(padding: EdgeInsets.only(left: 8, right: 8), width: 1, height: 24, color: AppTheme.separator),
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
      ],
    );
  }

  Widget _buildNavigation(String location, bool showMenu, BuildContext context) {
    return showMenu
        ? Builder(
            builder: (context) => WidgetsButton(
              icon: Icons.menu,
              padding: const EdgeInsets.all(8),
              iconSize: 20,
              minimumSize: const Size(40, 40),
              tooltip: "Open menu",
              evaluator: (s) {},
              onPressed: (s) async {
                Scaffold.of(context).openDrawer();
              },
            ),
          )
        : Wrap(
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
          );
  }
}
