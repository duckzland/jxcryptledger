import 'dart:convert';
import 'package:pinyin/pinyin.dart';

List<Map<String, dynamic>> cryptosParser(Map args) {
  final String body = args['body'];

  final decoded = jsonDecode(body);
  final List values = decoded["values"];

  final List<Map<String, dynamic>> result = [];

  for (final item in values) {
    try {
      final id = item[0] as int;
      final name = item[1] as String;
      final symbol = item[2] as String;
      final isActive = item[4] as int;
      final status = item[5] as int;

      if (id == 0 || isActive == 0 || status == 0) {
        continue;
      }

      final cleanedName = name.trim().replaceAll(
        RegExp(r'[^a-zA-Z0-9\u4e00-\u9fff]'),
        "",
      );

      final pinyin = PinyinHelper.getPinyin(cleanedName, separator: "");

      result.add({
        "id": id,
        "name": pinyin.toLowerCase(),
        "symbol": symbol.trim().toUpperCase(),
        "status": status,
        "active": isActive,
      });
    } catch (_) {
      // skip invalid entry
    }
  }

  return result;
}
