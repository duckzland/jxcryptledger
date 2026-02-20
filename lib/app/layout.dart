import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/locator.dart';
import '../../features/cryptos/service.dart';
import '../../features/rates/service.dart';
import '../../features/rates/model.dart';

class AppLayout extends StatelessWidget {
  final String title;
  final bool showBack;
  final Widget child;

  const AppLayout({
    super.key,
    required this.title,
    required this.child,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        locator<CryptosService>(),
        locator<RatesService>(),
      ]),
      builder: (context, _) {
        final cryptosService = locator<CryptosService>();
        final ratesService = locator<RatesService>();

        final fetchingCryptos = cryptosService.isFetching;
        final fetchingRates = ratesService.isFetching;

        final hasRates = ratesService.hasRates;

        return Scaffold(
          appBar: AppBar(
            leading: showBack
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
            title: Text(title),
            actions: [
              // Refresh Cryptos
              Container(
                decoration: BoxDecoration(
                  color: fetchingCryptos
                      ? Colors.blue.withOpacity(0.25)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: fetchingCryptos
                      ? null
                      : () async {
                          await cryptosService.fetch();
                        },
                ),
              ),

              // Refresh Rates
              if (hasRates)
                Container(
                  decoration: BoxDecoration(
                    color: fetchingRates
                        ? Colors.green.withOpacity(0.25)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.autorenew),
                    onPressed: (fetchingRates || fetchingCryptos)
                        ? null
                        : () async {
                            await ratesService.refreshRates();
                          },
                  ),
                ),

              // Settings
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => context.go("/settings"),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: child,
          ),
        );
      },
    );
  }
}
