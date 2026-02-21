import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/root.dart';
import 'app/storage.dart';
import 'core/locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  await AppStorage.instance.init();

  setupLocator();

  runApp(const AppRoot());
}
