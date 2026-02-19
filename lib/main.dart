import 'package:flutter/material.dart';

import 'app/root.dart';
import 'app/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppStorage.instance.init();

  runApp(const AppRoot());
}
