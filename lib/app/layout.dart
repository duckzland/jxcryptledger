import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/rates/controller.dart';
import '../core/locator.dart';
import '../features/cryptos/controller.dart';
import '../widgets/button.dart';
import '../widgets/notify.dart';
import '../widgets/separator.dart';
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

  List<Map<String, Object>> menus = [
    {
      "icon": Icons.account_balance_wallet,
      "title": "Manage Transactions",
      "target": "/transactions",
      "evaluator": (location) => (location == "/transactions" || location == "/"),
      "ordering": 0,
    },
    {
      "icon": Icons.candlestick_chart,
      "title": "Display Watchboard",
      "target": "/watchboard",
      "evaluator": (location) => (location == "/watchboard"),
      "ordering": 1,
    },
    {
      "icon": Icons.add_alarm,
      "title": "Manage Rate Watchers",
      "target": "/watchers",
      "evaluator": (location) => (location == "/watchers"),
      "ordering": 2,
    },
    {
      "icon": Icons.handyman,
      "title": "Use Crypto Tools",
      "target": "/tools",
      "evaluator": (location) => (location == "/tools"),
      "ordering": 3,
    },
    {
      "icon": Icons.settings,
      "title": "Settings",
      "target": "/settings",
      "evaluator": (location) => (location == "/settings"),
      "ordering": 4,
    },
  ];

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
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final double leadingWidth = width < 800 ? 0 : 210;
            final showMenu = width < 800;

            return Scaffold(
              drawer: (showMenu) ? _buildDrawer(location, context) : null,
              appBar: AppBar(
                backgroundColor: AppTheme.columnHeaderBg,
                leadingWidth: leadingWidth,
                leading: (showMenu) ? const SizedBox.shrink() : _buildLeading(leadingWidth),
                title: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.of(context).size.width;
                    return SizedBox(
                      width: width,
                      child: Row(
                        spacing: 8,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          (showMenu) ? _buildMenuToggler(context) : _buildNavigation(location),

                          WidgetsSeparator(),

                          if (_actions != null) Expanded(key: Key("bid-$_barBuildId"), child: _actions!),
                        ],
                      ),
                    );
                  },
                ),
                actions: (!showMenu) ? [_buildActions()] : [],
              ),
              body: Padding(padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8), child: widget.child),
            );
          },
        );
      },
    );
  }

  Widget _buildDrawer(String location, BuildContext context) {
    final hasRates = _ratesController.hasRates;

    List<Widget> navigation = [];
    menus.sort((a, b) => (a['ordering'] as int).compareTo(b['ordering'] as int));

    for (var menu in menus) {
      final evaluator = menu['evaluator'] as bool Function(String);
      navigation.add(
        ListTile(
          leading: Icon(menu['icon'] as IconData),
          title: Text(menu['title'] as String),
          selected: evaluator(location),
          selectedColor: AppTheme.text,
          selectedTileColor: AppTheme.primary,
          onTap: () {
            Navigator.pop(context);
            context.go(menu['target'] as String);
          },
        ),
      );
    }

    return Drawer(
      child: ListView(
        children: [
          Container(
            height: 60,
            color: AppTheme.menuHeaderBg,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(_title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),

          ...navigation,

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

  Widget _buildLeading(double width) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Container(
          padding: EdgeInsets.only(left: 16.0),
          decoration: BoxDecoration(
            color: AppTheme.panelBg,
            borderRadius: const BorderRadius.only(topRight: Radius.circular(4), bottomRight: Radius.circular(4)),
          ),
          child: SizedBox(
            height: 42,
            width: width - 16,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(_title, style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    final hasRates = _ratesController.hasRates;
    return Padding(
      padding: EdgeInsets.only(right: 16.0),
      child: Row(
        spacing: 8,
        children: [
          WidgetsSeparator(padding: EdgeInsets.only(left: 8, right: 8)),
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
      ),
    );
  }

  Widget _buildMenuToggler(BuildContext context) {
    return Builder(
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
    );
  }

  Widget _buildNavigation(String location) {
    List<Widget> navigation = [];
    menus.sort((a, b) => (a['ordering'] as int).compareTo(b['ordering'] as int));

    for (var menu in menus) {
      navigation.add(
        WidgetsButton(
          icon: menu['icon'] as IconData,
          padding: const EdgeInsets.all(8),
          iconSize: 20,
          minimumSize: const Size(40, 40),
          tooltip: menu['title'] as String,
          evaluator: (s) {
            final evaluator = menu['evaluator'] as bool Function(String);
            if (evaluator(location)) {
              s.active();
            } else {
              s.normal();
            }
          },
          onPressed: (s) {
            context.go(menu['target'] as String);
          },
        ),
      );
    }

    return Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: navigation);
  }
}
