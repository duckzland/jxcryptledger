import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/constants.dart';
import 'app/root.dart';
import 'core/runtime/client.dart';
import 'core/runtime/server.dart';
import 'core/runtime/locator.dart';

Future<void> main(List<String> args) async {
  if (Platform.isWindows == false && Platform.isLinux == false) {
    throw ("App only support windows or linux");
  }

  if (kIsWeb) {
    throw ("App only doesn't support web mode");
  }

  WidgetsFlutterBinding.ensureInitialized();

  if (File('.env').existsSync()) {
    await dotenv.load(fileName: ".env", isOptional: true);
  } else {
    dotenv.loadFromString(envString: "APP_SALT=$appSalt");
  }

  setupLocator();

  if (args.contains("--server")) {
    await locator<CoreRuntimeServer>().init();
  } else {
    await locator<CoreRuntimeClient>().init();
    runApp(const AppRoot());
  }
}
