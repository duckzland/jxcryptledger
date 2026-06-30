import 'dart:io';
import 'package:intl/intl.dart';

import 'runtime/runtime.dart';

final DateFormat _fmt = DateFormat('HH:mm:ss.SSSSSS');

const bool isProd = bool.fromEnvironment('dart.vm.product');

void logln(String message) {
  if (isProd) return;

  String prefix = CoreRuntime.instance.isServer() ? "[SRV]" : "[CLT]";
  final ts = _fmt.format(DateTime.now());

  if (CoreRuntime.instance.isServer()) {
    try {
      final file = File('server_log.txt');
      file.writeAsStringSync('[JX]$prefix $ts - $message\n', mode: FileMode.append, flush: true);
    } catch (e) {}
  } else {
    stdout.writeln('[JX]$prefix $ts - $message');
  }
}
