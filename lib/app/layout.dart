import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/cryptos/service.dart';
import '../../features/rates/service.dart';
import '../core/locator.dart';
import 'button.dart';

class AppLayout extends StatefulWidget {
  final String title;
  final bool showBack;
  final Widget child;

  const AppLayout({super.key, required this.title, required this.child, this.showBack = false});

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([locator<CryptosService>(), locator<RatesService>()]),
      builder: (context, _) {
        final cryptosService = locator<CryptosService>();
        final ratesService = locator<RatesService>();

        final hasRates = ratesService.hasRates;

        final location = GoRouterState.of(context).uri.toString();

        // logln("message: Building AppLayout for location: $location");

        return Scaffold(
          appBar: AppBar(
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
            title: Text(widget.title),
            actions: [
              Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppButton(
                    icon: Icons.refresh,
                    padding: const EdgeInsets.all(8),
                    iconSize: 20,
                    minimumSize: const Size(40, 40),
                    tooltip: "Refresh Cryptos",
                    onPressed: (s) async {
                      s.progress();
                      await cryptosService.fetch();
                      s.reset();
                    },
                  ),

                  if (hasRates)
                    AppButton(
                      icon: Icons.autorenew,
                      padding: const EdgeInsets.all(8),
                      iconSize: 20,
                      minimumSize: const Size(40, 40),
                      tooltip: "Refresh Rates",
                      onPressed: (s) async {
                        s.progress();
                        await ratesService.refreshRates();
                        s.reset();
                      },
                    ),

                  AppButton(
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
