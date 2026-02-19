import 'dart:math';

/// General-purpose utility helpers for the app.
class Utils {
  Utils._();

  /// Safely parses an int. Returns null if invalid.
  static int? tryParseInt(String? value) {
    if (value == null) return null;
    return int.tryParse(value.trim());
  }

  /// Safely parses a double. Returns null if invalid.
  static double? tryParseDouble(String? value) {
    if (value == null) return null;
    return double.tryParse(value.trim());
  }

  /// Formats a DateTime as yyyy-MM-dd HH:mm:ss
  static String formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:$s';
  }

  /// Deep copy of a Map<String, dynamic>.
  static Map<String, dynamic> deepCopyMap(Map<String, dynamic> source) {
    return Map<String, dynamic>.from(source);
  }

  /// Deep copy of a List<Map<String, dynamic>>.
  static List<Map<String, dynamic>> deepCopyList(
    List<Map<String, dynamic>> source,
  ) {
    return source.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Generates a random alphanumeric ID.
  static String randomId([int length = 12]) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }
}

/// Simple debounce helper for search/filter UI.
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
