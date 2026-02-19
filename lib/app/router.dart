import 'package:go_router/go_router.dart';

import '../features/unlock/page.dart';
import '../features/unlock/controller.dart';

import '../features/transactions/page.dart';
import '../features/transactions/page_single.dart';

import '../features/settings/page.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: "/unlock",
    routes: [
      GoRoute(
        path: "/unlock",
        builder: (context, state) => UnlockPage(controller: UnlockController()),
      ),
      GoRoute(
        path: "/transactions",
        builder: (context, state) => const TransactionsPage(),
      ),
      GoRoute(
        path: "/transaction_detail",
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>;
          return TransactionsPageSingle(data: data);
        },
      ),
      GoRoute(
        path: "/settings",
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
}
