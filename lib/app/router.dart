import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/layout.dart';
import '../features/settings/page.dart';
import '../features/transactions/pages/index.dart';
import '../features/unlock/controller.dart';
import '../features/unlock/page.dart';

class AppRouter {
  static bool _showBackFor(String location) {
    if (location == "/transactions") return false;
    if (location == "/unlock") return false;
    return true;
  }

  static final router = GoRouter(
    initialLocation: "/unlock",

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
        builder: (context, state, child) {
          final location = state.uri.toString();

          return AppLayout(title: _titleFor(location), showBack: _showBackFor(location), child: child);
        },
        routes: [
          GoRoute(path: "/transactions", builder: (context, state) => const TransactionsPagesIndex()),

          GoRoute(path: "/settings", builder: (context, state) => const SettingsPage()),
        ],
      ),
    ],
  );

  static String _titleFor(String location) {
    if (location.startsWith("/settings")) return "Settings";
    if (location.startsWith("/transaction_detail")) return "Transaction Detail";
    return "Transactions";
  }
}
