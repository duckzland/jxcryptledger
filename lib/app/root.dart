import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../core/locator.dart';
import '../core/log.dart';

import '../ipc/client.dart';
import '../ipc/status/op.dart';

import '../mixins/state.dart';

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
  void reassemble() async {
    super.reassemble();

    if (kDebugMode || kProfileMode) {
      try {
        final ipcClient = CoreLocator.getit<IpcClient>();
        await ipcClient.send(op: IpcStatusOp.getCode("reload"), action: "reload");
      } catch (e) {
        logln("Failed to reload server: $e", "APP");
      }
    }
  }

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

        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.noScaling),
          child: ScrollConfiguration(behavior: AppScrollBehavior(), child: child!),
        );
      },
    );
  }
}
