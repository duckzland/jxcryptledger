import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/layout.dart';
import '../core/mode.dart';
import '../features/archives/page.dart';
import '../system/error/page.dart';
import '../system/settings/page.dart';
import '../features/watchboard/page.dart';
import '../features/tools/page.dart';
import '../features/transactions/page.dart';
import '../system/unlock/page.dart';
import '../features/watchers/page.dart';
import 'page.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static Page<dynamic> buildPage(BuildContext context, GoRouterState state, Widget child) {
    final location = state.uri.toString();
    String title = "";
    if (location.startsWith("/transactions")) title = "Transactions";
    if (location.startsWith("/settings")) title = "Settings";
    if (location.startsWith("/watchers")) title = "Rate Watchers";
    if (location.startsWith("/watchboard")) title = "Watchboard";
    if (location.startsWith("/archives")) title = "Data Archives";
    if (location.startsWith("/tools")) title = "Tools";

    Widget page = AppPage(key: const ValueKey("main-page"), child: child);

    if (!location.startsWith("/error") && !location.startsWith("/unlock")) {
      page = AppLayout(key: const ValueKey("main-layout"), title: title, child: page);
    }

    return NoTransitionPage(key: const ValueKey("main-page-transition"), child: page);
  }

  static GoRouter router = GoRouter(
    routerNeglect: true,
    initialLocation: "/unlock",
    navigatorKey: rootNavigatorKey,
    redirect: (context, state) {
      final bool isAppUnlocked = CoreMode.isUnlocked;
      final String targetedPath = state.uri.path;
      final bool headingToUnlock = targetedPath == "/unlock";
      final bool headingToError = targetedPath == "/error";

      if (!isAppUnlocked && !headingToUnlock && !headingToError) {
        return "/unlock";
      }

      if (isAppUnlocked && headingToUnlock) {
        return "/transactions";
      }

      return null;
    },
    routes: [
      ShellRoute(
        pageBuilder: (context, state, child) => NoTransitionPage(key: const ValueKey("main-page-transition"), child: child),
        routes: [
          GoRoute(
            path: "/unlock",
            pageBuilder: (context, state) => buildPage(context, state, SystemUnlockPage(key: const ValueKey("main-content"))),
          ),
          GoRoute(
            path: "/error",
            pageBuilder: (context, state) => buildPage(context, state, SystemErrorPage(key: const ValueKey("main-content"))),
          ),
          GoRoute(
            path: "/transactions",
            pageBuilder: (context, state) => buildPage(context, state, TransactionsPage(key: const ValueKey("main-content"))),
          ),
          GoRoute(
            path: "/watchboard",
            pageBuilder: (context, state) => buildPage(context, state, WatchboardPage(key: const ValueKey("main-content"))),
          ),
          GoRoute(
            path: "/watchers",
            pageBuilder: (context, state) => buildPage(context, state, WatchersPage(key: const ValueKey("main-content"))),
          ),
          GoRoute(
            path: "/archives",
            pageBuilder: (context, state) => buildPage(context, state, ArchivesPage(key: const ValueKey("main-content"))),
          ),
          GoRoute(
            path: "/tools",
            pageBuilder: (context, state) => buildPage(context, state, ToolsPage(key: const ValueKey("main-content"))),
          ),
          GoRoute(
            path: "/settings",
            pageBuilder: (context, state) => buildPage(context, state, SettingsPage(key: const ValueKey("main-content"))),
          ),
        ],
      ),
    ],
  );
}
