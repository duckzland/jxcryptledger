import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/layout.dart';
import '../core/mode.dart';
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

class AppRouter {
  static final router = GoRouter(
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
      GoRoute(
        path: "/transactions",
        pageBuilder: (context, state) {
          return NoTransitionPage(
            key: state.pageKey,
            child: AppLayout(
              title: "Transactions",
              child: const AppPage(child: TransactionsPage()),
            ),
          );
        },
      ),
      GoRoute(
        path: "/watchboard",
        pageBuilder: (context, state) {
          return NoTransitionPage(
            key: state.pageKey,
            child: AppLayout(
              title: "Watchboard",
              child: const AppPage(child: WatchboardPage()),
            ),
          );
        },
      ),
      GoRoute(
        path: "/watchers",
        pageBuilder: (context, state) {
          return NoTransitionPage(
            key: state.pageKey,
            child: AppLayout(
              title: "Rate Watchers",
              child: const AppPage(child: WatchersPage()),
            ),
          );
        },
      ),
      GoRoute(
        path: "/archives",
        pageBuilder: (context, state) {
          return NoTransitionPage(
            key: state.pageKey,
            child: AppLayout(
              title: "Data Archives",
              child: const AppPage(child: ArchivesPage()),
            ),
          );
        },
      ),
      GoRoute(
        path: "/tools",
        pageBuilder: (context, state) {
          return NoTransitionPage(
            key: state.pageKey,
            child: AppLayout(
              title: "Tools",
              child: const AppPage(child: ToolsPage()),
            ),
          );
        },
      ),
      GoRoute(
        path: "/settings",
        pageBuilder: (context, state) {
          return NoTransitionPage(
            key: state.pageKey,
            child: AppLayout(
              title: "Settings",
              child: const AppPage(child: SettingsPage()),
            ),
          );
        },
      ),
    ],
  );
}
