import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/settings/page.dart';
import '../features/transactions/page.dart';
import '../features/transactions/page_single.dart';
import '../features/unlock/controller.dart';
import '../features/unlock/page.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: "/unlock",
    routes: [
      GoRoute(
        path: '/unlock',
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

      GoRoute(path: "/transactions", builder: (context, state) => const TransactionsPage()),
      GoRoute(
        path: "/transaction_detail",
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>;
          return TransactionsPageSingle(data: data);
        },
      ),
      GoRoute(path: "/settings", builder: (context, state) => const SettingsPage()),
    ],
  );
}
