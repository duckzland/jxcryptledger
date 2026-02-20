import 'dart:math';

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
