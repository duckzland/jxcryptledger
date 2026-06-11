import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../core/log.dart';
import 'router.dart';
import 'state.dart';
import 'theme.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
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
      await AppState.instance.save();
      return AppExitResponse.exit;
    } catch (e) {
      logln("Failed to save state on exit: $e");
      return AppExitResponse.exit;
    }
  }

  Future<void> _handleTerminalExit() async {
    try {
      await AppState.instance.save();
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
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: child!,
        );
      },
    );
  }
}
