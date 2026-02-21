import 'dart:math';

import 'package:decimal/decimal.dart';

class Utils {
  Utils._();

  static int? tryParseInt(String? value) {
    if (value == null) return null;
    return int.tryParse(value.trim());
  }

  static double? tryParseDouble(String? value) {
    if (value == null) return null;
    return double.tryParse(value.trim());
  }

  static String formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:$s';
  }

  static String formatSmartDouble(double value) {
    // Convert double → Decimal (removes floating‑point noise)
    final dec = Decimal.parse(value.toString());

    // Convert Decimal → exact string
    String s = dec.toString();

    // If there's no decimal point, just add commas and return
    if (!s.contains('.')) {
      final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
      return s.replaceAllMapped(reg, (m) => ',');
    }

    // Split integer + fractional parts
    final parts = s.split('.');
    String intPart = parts[0];
    String fracPart = parts[1];

    // Trim trailing zeros in fractional part
    fracPart = fracPart.replaceFirst(RegExp(r'0+$'), '');

    // Add comma separators to integer part
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    intPart = intPart.replaceAllMapped(reg, (m) => ',');

    // Recombine
    return fracPart.isEmpty ? intPart : '$intPart.$fracPart';
  }

  static Map<String, dynamic> deepCopyMap(Map<String, dynamic> source) {
    return Map<String, dynamic>.from(source);
  }

  static List<Map<String, dynamic>> deepCopyList(List<Map<String, dynamic>> source) {
    return source.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static String randomId([int length = 12]) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  static String formatDate(int timestamp) {
    final isMilliseconds = timestamp > 2000000000; // ~2033 in seconds

    final date = isMilliseconds
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

class Debouncer {
  Debouncer({required this.delay});

  final Duration delay;
  void Function()? _action;
  bool _isScheduled = false;

  void call(void Function() action) {
    _action = action;

    if (_isScheduled) return;
    _isScheduled = true;

    Future.delayed(delay, () {
      _isScheduled = false;
      _action?.call();
    });
  }
}
