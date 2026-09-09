import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../mixins/state.dart';
import '../widgets/debug.dart';

import 'router.dart';
import 'scroll_behavior.dart';
import 'theme.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with MixinsState {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'JXLedger',
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.router,
      builder: (context, child) {
        final mq = MediaQuery.of(context);

        states.set('viewport-width', mq.size.width);
        states.set('viewport-height', mq.size.height);

        Widget content = child!;

        if (kDebugMode || kProfileMode) {
          content = Column(
            children: [
              Expanded(child: content),
              const WidgetsDebug(),
            ],
          );
        }

        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.noScaling),
          child: ScrollConfiguration(behavior: AppScrollBehavior(), child: content),
        );
      },
    );
  }
}
