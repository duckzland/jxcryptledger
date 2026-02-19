import 'package:flutter/material.dart';

import 'app/root.dart';
import 'app/storage.dart';
import 'core/locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppStorage.instance.init();

  setupLocator();

  runApp(const AppRoot());
}
