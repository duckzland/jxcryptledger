import 'dart:io';
import 'package:intl/intl.dart';

final DateFormat _fmt = DateFormat('HH:mm:ss.SSSSSS');

const bool isProd = bool.fromEnvironment('dart.vm.product');

void logln(String message) {
  if (isProd) return;

  final ts = _fmt.format(DateTime.now());
  stdout.writeln('[JX] $ts - $message');
}
