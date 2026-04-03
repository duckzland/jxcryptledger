import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/root.dart';
import 'app/storage.dart';
import 'core/locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (File('.env').existsSync()) {
    await dotenv.load(fileName: ".env", isOptional: true);
  }

  await AppStorage.instance.init();

  setupLocator();

  runApp(const AppRoot());
}
