import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

final DateFormat _fmt = DateFormat('HH:mm:ss.SSSSSS');

void Logln(String message) {
  if (!kDebugMode) return;

  final ts = _fmt.format(DateTime.now());
  print('[JX] $ts - $message');
}
