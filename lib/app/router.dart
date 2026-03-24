import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/layout.dart';
import '../features/settings/page.dart';
import '../features/watchboard/page.dart';
import '../features/tools/page.dart';
import '../features/transactions/page.dart';
import '../features/unlock/controller.dart';
import '../features/unlock/page.dart';
import '../features/watchers/page.dart';
import 'page.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static final router = GoRouter(
    initialLocation: "/unlock",
    navigatorKey: rootNavigatorKey,

    routes: [
      GoRoute(
        path: "/unlock",
        builder: (context, state) {
          final c = UnlockController();
          return FutureBuilder(
            future: c.init(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              return UnlockPage(controller: c);
            },
          );
        },
      ),

      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          final location = state.uri.toString();

          return AppLayout(title: _titleFor(location), child: child);
        },
        routes: [
          GoRoute(path: "/", redirect: (context, state) => "/transactions"),
          GoRoute(
            path: "/transactions",
            builder: (context, state) => const AppPage(child: TransactionsPage()),
          ),

          GoRoute(
            path: "/watchboard",
            builder: (context, state) => const AppPage(child: WatchboardPage()),
          ),
          GoRoute(
            path: "/watchers",
            builder: (context, state) => const AppPage(child: WatchersPage()),
          ),
          GoRoute(
            path: "/tools",
            builder: (context, state) => const AppPage(child: ToolsPage()),
          ),
          GoRoute(
            path: "/settings",
            builder: (context, state) => const AppPage(child: SettingsPage()),
          ),
        ],
      ),
    ],
  );

  static String _titleFor(String location) {
    if (location.startsWith("/settings")) return "Settings";
    if (location.startsWith("/watchers")) return "Rate Watchers";
    if (location.startsWith("/watchboard")) return "Watchboard";
    return "Transactions";
  }
}
