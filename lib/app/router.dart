import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/layout.dart';
import '../features/archives/page.dart';
import '../system/error/controller.dart';
import '../system/error/page.dart';
import '../system/settings/page.dart';
import '../features/watchboard/page.dart';
import '../features/tools/page.dart';
import '../features/transactions/page.dart';
import '../system/unlock/controller.dart';
import '../system/unlock/page.dart';
import '../features/watchers/page.dart';
import 'page.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();

Page customPageBuilder(GoRouterState state, Widget child) {
  return NoTransitionPage(
    key: state.pageKey,
    child: AppPage(child: child),
  );
}

class AppRouter {
  static final router = GoRouter(
    initialLocation: "/unlock",
    navigatorKey: rootNavigatorKey,

    routes: [
      GoRoute(
        path: "/unlock",
        pageBuilder: (context, state) {
          final c = SystemUnlockController();
          return NoTransitionPage(
            key: state.pageKey,
            child: AppPage(
              child: FutureBuilder(
                future: c.init(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Scaffold(body: Center(child: CircularProgressIndicator()));
                  }
                  return SystemUnlockPage(controller: c);
                },
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: "/error",
        pageBuilder: (context, state) {
          final c = SystemErrorController();
          return NoTransitionPage(
            key: state.pageKey,
            child: AppPage(
              child: FutureBuilder(
                future: c.init(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Scaffold(body: Center(child: CircularProgressIndicator()));
                  }
                  return SystemErrorPage(controller: c);
                },
              ),
            ),
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
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const AppPage(child: TransactionsPage()),
            ),
          ),
          GoRoute(
            path: "/watchboard",
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const AppPage(child: WatchboardPage()),
            ),
          ),
          GoRoute(
            path: "/watchers",
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const AppPage(child: WatchersPage()),
            ),
          ),
          GoRoute(
            path: "/archives",
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const AppPage(child: ArchivesPage()),
            ),
          ),
          GoRoute(
            path: "/tools",
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const AppPage(child: ToolsPage()),
            ),
          ),
          GoRoute(
            path: "/settings",
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const AppPage(child: SettingsPage()),
            ),
          ),
        ],
      ),
    ],
  );

  static String _titleFor(String location) {
    if (location.startsWith("/settings")) return "Settings";
    if (location.startsWith("/watchers")) return "Rate Watchers";
    if (location.startsWith("/watchboard")) return "Watchboard";
    if (location.startsWith("/archives")) return "Data Archives";
    if (location.startsWith("/tools")) return "Tools";
    return "Transactions";
  }
}
