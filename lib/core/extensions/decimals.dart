import 'package:decimal/decimal.dart';
import 'package:hive_ce/hive.dart';

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
    if (this is num) {
      return Decimal.parse((this as num).toString());
    }
    if (this is String) {
      return Decimal.tryParse(this as String);
    }
    return null;
  }
}
