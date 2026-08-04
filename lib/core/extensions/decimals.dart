import 'package:decimal/decimal.dart';
import 'package:hive_ce/hive.dart';

import '../utils.dart';

extension CoreExtensionsDecimalReader on BinaryReader {
  Decimal readDecimal() {
    final String rawStr = readString();
    return Decimal.tryParse(rawStr) ?? Decimal.zero;
  }
}

extension CoreExtensionsDecimalWriter on BinaryWriter {
  void writeDecimal(Decimal value) {
    writeString(value.toString());
  }
}

extension CoreExtensionsDecimalObject on Object? {
  Decimal? toDecimal() {
    if (this == null) return null;
    if (this is Decimal) {
      return this as Decimal;
    }
    if (this is num) {
      return Utils.parseDecimalFromObject(this);
    }
    if (this is String) {
      return Utils.parseDecimal(this as String);
    }
    return null;
  }
}
