import 'dart:io';
import 'package:intl/intl.dart';

import 'mode.dart';

final DateFormat _fmt = DateFormat('HH:mm:ss.SSSSSS');

const bool isProd = bool.fromEnvironment('dart.vm.product');

void logln(String message) {
  if (isProd) return;

  String prefix = CoreMode.isServer ? "[SRV]" : "[CLT]";
  final ts = _fmt.format(DateTime.now());

  if (CoreMode.isServer) {
    try {
      final file = File('server_log.txt');
      file.writeAsStringSync('[JX]$prefix $ts - $message\n', mode: FileMode.append, flush: true);
    } catch (e) {
      stdout.writeln('[JX]$prefix $ts - Failed to write log: $e');
    }
  } else {
    stdout.writeln('[JX]$prefix $ts - $message');
  }
}
