import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/rates/controller.dart';
import '../features/cryptos/controller.dart';
import '../ipc/client.dart';
import '../ipc/event.dart';
import '../ipc/mixins/broadcaster.dart';
import '../ipc/server.dart';
import '../ipc/status/op.dart';
import '../widgets/buttons/action.dart';
import '../widgets/notify.dart';
import '../widgets/separator.dart';
import '../core/locator.dart';
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

class _AppLayoutState extends State<AppLayout> with IpcMixinsBroadcaster {
  CryptosController get _cryptosController => CoreLocator.getit<CryptosController>();
  RatesController get _ratesController => CoreLocator.getit<RatesController>();

  @override
  IpcClient get ipcClient => CoreLocator.getit<IpcClient>();

  @override
  IpcServer get ipcServer => CoreLocator.getit<IpcServer>();

  void _setTitle(String newTitle) {
    _title.value = newTitle;
  }

  void _setActions(Widget? actions) {
    _actions.value = actions;
  }

  void _refreshBar() {
    _actions.value = _actions.value;
  }

  List<Map<String, Object>> get menus => [
    {
      "icon": Icons.account_balance_wallet,
      "title": "Manage transactions",
      "target": "/transactions",
      "evaluator": (location) => (location == "/transactions" || location == "/"),
      "ordering": 0,
    },
    {
      "icon": Icons.candlestick_chart,
      "title": "Display watchboard",
      "target": "/watchboard",
      "evaluator": (location) => (location == "/watchboard"),
      "ordering": 1,
    },
    {
      "icon": Icons.add_alarm,
      "title": "Manage rate watchers",
      "target": "/watchers",
      "evaluator": (location) => (location == "/watchers"),
      "ordering": 2,
    },
    {
      "icon": Icons.archive,
      "title": "Manage data archives",
      "target": "/archives",
      "evaluator": (location) => (location == "/archives"),
      "ordering": 3,
    },
    {
      "icon": Icons.handyman,
      "title": "Use crypto tools",
      "target": "/tools",
      "evaluator": (location) => (location == "/tools"),
      "ordering": 4,
    },
    {
      "icon": Icons.settings,
      "title": "Settings",
      "target": "/settings",
      "evaluator": (location) => (location == "/settings"),
      "ordering": 5,
    },
  ];

  final ValueNotifier<Widget?> _actions = ValueNotifier(null);
  final ValueNotifier<String?> _title = ValueNotifier(null);

  @override
  void initState() {
    super.initState();

    _title.value = widget.title;

    AppLayout.setTitle = _setTitle;
    AppLayout.setActions = _setActions;
    AppLayout.refreshBar = _refreshBar;

    broadcasterListen();
  }

  @override
  void broadcasterAction(IpcBroadcastEvent event) {
    if (event.op == IpcStatusOp.getCode("broadcast") && event.action == "notify") {
      switch (event.key) {
        case "success":
          widgetsNotifySuccess(event.payload);
        case "error":
          widgetsNotifyError(event.payload);
        case "warning":
          widgetsNotifyWarning(event.payload);
        default:
          break;
      }
    }
  }

  @override
  void dispose() {
    broadcasterDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final location = GoRouterState.of(context).uri.toString();
        final width = constraints.maxWidth;
        final double leadingWidth = width < 800 ? 0 : 210;
        final showMenu = width < 800;

        return Scaffold(
          drawer: (showMenu) ? _buildDrawer(location, context) : null,
          appBar: AppBar(
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

                      const WidgetsSeparator(),

                      Expanded(
                        child: ValueListenableBuilder<Widget?>(
                          valueListenable: _actions,
                          builder: (_, actions, _) {
                            return actions ?? const SizedBox.shrink();
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: (!showMenu) ? [_buildActions()] : [],
          ),
          body: Padding(padding: EdgeInsets.only(left: 0, right: 0, top: 8, bottom: 8), child: widget.child),
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
          key: ValueKey(menu['target']),
          leading: Icon(menu['icon'] as IconData),
          title: Text(menu['title'] as String),
          selected: evaluator(location),
          selectedColor: AppTheme.text,
          selectedTileColor: AppTheme.primary,
          onTap: () {
            Navigator.pop(context);
            Router.neglect(context, () {
              context.go(menu['target'] as String);
            });
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
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: ValueListenableBuilder<String?>(
              valueListenable: _title,
              builder: (_, title, _) {
                return title != null ? Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)) : const SizedBox.shrink();
              },
            ),
          ),

          ...navigation,

          const Divider(),

          ListTile(
            key: Key('refresh-cryptos'),
            leading: Icon(Icons.refresh),
            title: Text("Refresh Cryptos"),
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
              key: Key('refresh-rates'),
              leading: Icon(Icons.autorenew),
              title: Text("Refresh Rates"),
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
            key: Key('close-menu'),
            leading: Icon(Icons.close),
            title: Text("Close Menu"),
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
            color: AppTheme.appBarTitleBg,
            borderRadius: BorderRadius.only(topRight: Radius.circular(4), bottomRight: Radius.circular(4)),
          ),
          child: SizedBox(
            height: 42,
            width: width - 16,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ValueListenableBuilder<String?>(
                valueListenable: _title,
                builder: (_, title, _) {
                  return title != null ? Text(title, style: AppTheme.text700) : const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
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
              ListenableBuilder(
                listenable: _cryptosController,
                builder: (context, _) {
                  return WidgetsButtonsAction(
                    key: const Key("refresh-crypto"),
                    icon: Icons.refresh,
                    padding: EdgeInsets.all(8),
                    iconSize: 20,
                    minimumSize: const Size(40, 40),
                    tooltip: "Refresh Cryptos",
                    evaluator: (s) {
                      _cryptosController.isFetching ? s.progress() : s.reset();
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
                  );
                },
              ),

              ListenableBuilder(
                listenable: _ratesController,
                builder: (context, _) {
                  return _ratesController.hasRates
                      ? WidgetsButtonsAction(
                          key: const Key("refresh-rates"),
                          icon: Icons.autorenew,
                          padding: EdgeInsets.all(8),
                          iconSize: 20,
                          minimumSize: const Size(40, 40),
                          tooltip: "Refresh Rates",
                          evaluator: (s) {
                            _ratesController.isFetching ? s.progress() : s.reset();
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
                        )
                      : const SizedBox.shrink();
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
      builder: (context) => WidgetsButtonsAction(
        key: const Key("menu-toggler"),
        icon: Icons.menu,
        padding: EdgeInsets.all(8),
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
        WidgetsButtonsAction(
          key: ValueKey(menu['target']),
          icon: menu['icon'] as IconData,
          padding: EdgeInsets.all(8),
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
            Router.neglect(context, () {
              context.go(menu['target'] as String);
            });
          },
        ),
      );
    }

    return Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: navigation);
  }
}
