import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fontLoader = FontLoader('Inter');
  const fontFiles = [
    'assets/fonts/Inter-Thin.ttf',
    'assets/fonts/Inter-ExtraLight.ttf',
    'assets/fonts/Inter-Light.ttf',
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
    'assets/fonts/Inter-Bold.ttf',
    'assets/fonts/Inter-ExtraBold.ttf',
    'assets/fonts/Inter-Black.ttf',
  ];

  for (final path in fontFiles) {
    final file = File(path);
    if (file.existsSync()) {
      final bytes = await file.readAsBytes();
      fontLoader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
  }

  await fontLoader.load();
  await testMain();
}
