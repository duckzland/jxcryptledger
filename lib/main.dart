import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/root.dart';
import 'app/storage.dart';
import 'core/locator.dart';
import 'features/rates/service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  await AppStorage.instance.init();

  setupLocator();
  await locator<RatesService>().init();

  runApp(const AppRoot());
}
