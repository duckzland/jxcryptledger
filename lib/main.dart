import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/constants.dart';
import 'app/root.dart';
import 'core/runtime/runtime.dart';
import 'core/locator.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (File('.env').existsSync()) {
    await dotenv.load(fileName: ".env", isOptional: true);
  } else {
    dotenv.loadFromString(envString: "APP_SALT=$appSalt");
  }

  setupLocator();

  CoreRuntime.instance.setArgs(args);
  await CoreRuntime.instance.init();

  if (!args.contains('--server')) {
    runApp(const AppRoot());
  }
}
