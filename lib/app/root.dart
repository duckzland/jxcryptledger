import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../core/log.dart';
import '../mixins/state.dart';
import 'router.dart';
import 'theme.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with MixinsState {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();

    _lifecycleListener = AppLifecycleListener(onExitRequested: _handleWindowsWindowClose);

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      ProcessSignal.sigint.watch().listen((signal) async {
        await _handleTerminalExit();
      });
    }
  }

  Future<AppExitResponse> _handleWindowsWindowClose() async {
    try {
      await states.save();
      return AppExitResponse.exit;
    } catch (e) {
      logln("Failed to save state on exit: $e");
      return AppExitResponse.exit;
    }
  }

  Future<void> _handleTerminalExit() async {
    try {
      await states.save();
    } catch (e) {
      logln("Failed to save state on exit: $e");
    } finally {
      exit(0);
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
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
          child: child!,
        );
      },
    );
  }
}
