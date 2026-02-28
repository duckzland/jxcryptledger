import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/rates/controller.dart';
import '../core/locator.dart';
import '../features/cryptos/controller.dart';
import '../widgets/button.dart';
import 'theme.dart';

class AppLayout extends StatefulWidget {
  static void Function(String)? setTitle;

  final String title;
  final bool showBack;
  final Widget child;

  const AppLayout({super.key, required this.title, required this.child, this.showBack = false});

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  late String _title = widget.title;

  void _setTitle(String newTitle) {
    setState(() => _title = newTitle);
  }

  @override
  void initState() {
    super.initState();
    AppLayout.setTitle = _setTitle;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([locator<CryptosController>(), locator<RatesController>()]),
      builder: (context, _) {
        final cryptosController = locator<CryptosController>();
        final ratesController = locator<RatesController>();

        final hasRates = ratesController.hasRates;

        final location = GoRouterState.of(context).uri.toString();

        // logln("message: Building AppLayout for location: $location");

        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppTheme.columnHeaderBg,
            leading: widget.showBack
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go("/transactions");
                      }
                    },
                  )
                : null,
            title: Text(_title),
            actions: [
              Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  WidgetButton(
                    icon: Icons.refresh,
                    padding: const EdgeInsets.all(8),
                    iconSize: 20,
                    minimumSize: const Size(40, 40),
                    tooltip: "Refresh Cryptos",
                    onPressed: (s) async {
                      s.progress();
                      await cryptosController.fetch();
                      s.reset();
                    },
                  ),

                  if (hasRates)
                    WidgetButton(
                      icon: Icons.autorenew,
                      padding: const EdgeInsets.all(8),
                      iconSize: 20,
                      minimumSize: const Size(40, 40),
                      tooltip: "Refresh Rates",
                      onPressed: (s) async {
                        s.progress();
                        await ratesController.refreshRates();
                        s.reset();
                      },
                    ),

                  WidgetButton(
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
            ],
          ),
          body: Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), child: widget.child),
        );
      },
    );
  }
}
