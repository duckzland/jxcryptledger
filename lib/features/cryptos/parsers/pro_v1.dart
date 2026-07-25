import 'dart:convert';

import 'package:pinyin/pinyin.dart';

List<Map<String, dynamic>> cryptosParsersProV1(Map args) {
  final String body = args['body'];

  final decoded = jsonDecode(body);
  final List values = decoded["data"];

  final List<Map<String, dynamic>> result = [];

  for (final item in values) {
    try {
      final id = item['id'] as int;
      final symbol = item['symbol'] as String;
      final isActive = item['is_active'] as int;
      final statusName = item['status'] as String;

      int status;
      switch (statusName) {
        case 'active':
          status = 1;
        case 'inactive':
          status = 2;
        case 'untracked':
          status = 3;
        default:
          status = 0;
      }

      String name = item['name'] as String;

      if (id == 0 || isActive != 1) {
        continue;
      }

      final hasChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(name);

      if (hasChinese) {
        final cleanedName = name.trim().replaceAll(RegExp(r'[^a-zA-Z0-9\u4e00-\u9fff]'), "");
        final pinyin = PinyinHelper.getPinyin(cleanedName, separator: "");
        name = pinyin.toLowerCase();
      }

      result.add({"id": id, "name": name.trim(), "symbol": symbol.trim().toUpperCase(), "status": status, "active": isActive});
    } catch (_) {
      // skip invalid entry
    }
  }

  return result;
}
