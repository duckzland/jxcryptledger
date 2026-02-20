import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

final DateFormat _fmt = DateFormat('HH:mm:ss.SSSSSS');

void logln(String message) {
  if (!kDebugMode) return;

  final ts = _fmt.format(DateTime.now());
  debugPrint('[JX] $ts - $message');
}
