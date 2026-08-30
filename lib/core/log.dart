import 'dart:io';
import 'package:intl/intl.dart';

import 'mode.dart';

final DateFormat _fmt = DateFormat('HH:mm:ss.SSSSSS');

const bool isProd = bool.fromEnvironment('dart.vm.product');

void logln(String message, [String group = "CORE"]) {
  if (isProd) return;

  String prefix = CoreMode.isServer ? "SRV" : "CLT";
  final ts = _fmt.format(DateTime.now());

  if (CoreMode.isServer) {
    try {
      final file = File('server_log.txt');
      file.writeAsStringSync('[JX][$ts][$prefix][$group] $message\n', mode: FileMode.append, flush: true);
    } catch (e) {
      stdout.writeln('[JX][$ts][$prefix][$group] Failed to write log: $e');
    }
  } else {
    stdout.writeln('[JX][$ts][$prefix][$group] $message');
  }
}
