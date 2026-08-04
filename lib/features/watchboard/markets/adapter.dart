import 'package:hive_ce/hive_ce.dart';
import 'package:decimal/decimal.dart';
import '../../../core/extensions/decimals.dart';
import '../../../core/mode.dart';
import 'model.dart';

class MarketsAdapter extends TypeAdapter<MarketsModel> {
  @override
  final int typeId = 9;

  @override
  MarketsModel read(BinaryReader reader) {
    final String tid;
    final String name;
    final String symbol;
    final int rank;
    final bool isInfinite;
    final Decimal totalSupply;
    final Decimal maxSupply;
    final Decimal price;
    final Decimal volume24h;
    final Decimal volumeChange24h;
    final Decimal percent1h;
    final Decimal percent24h;
    final Decimal percent7d;
    final Decimal percent30d;
    final Decimal percent60d;
    final Decimal percent90d;
    final Decimal marketCap;
    final Decimal dominance;
    final Map<String, dynamic> meta;

    switch (CoreMode.dbVersion) {
      case "v1.1.0":
        tid = reader.readString();
        name = reader.readString();
        symbol = reader.readString();
        rank = reader.readInt();
        isInfinite = reader.readBool();
        totalSupply = Decimal.parse(reader.readDouble().toString());
        maxSupply = Decimal.parse(reader.readDouble().toString());
        price = Decimal.parse(reader.readDouble().toString());
        volume24h = Decimal.parse(reader.readDouble().toString());
        volumeChange24h = Decimal.parse(reader.readDouble().toString());
        percent1h = Decimal.parse(reader.readDouble().toString());
        percent24h = Decimal.parse(reader.readDouble().toString());
        percent7d = Decimal.parse(reader.readDouble().toString());
        percent30d = Decimal.parse(reader.readDouble().toString());
        percent60d = Decimal.parse(reader.readDouble().toString());
        percent90d = Decimal.parse(reader.readDouble().toString());
        marketCap = Decimal.parse(reader.readDouble().toString());
        dominance = Decimal.parse(reader.readDouble().toString());
        meta = Map<String, dynamic>.from(reader.readMap());
        break;

      default:
        tid = reader.readString();
        name = reader.readString();
        symbol = reader.readString();
        rank = reader.readInt();
        isInfinite = reader.readBool();
        totalSupply = reader.readDecimal();
        maxSupply = reader.readDecimal();
        price = reader.readDecimal();
        volume24h = reader.readDecimal();
        volumeChange24h = reader.readDecimal();
        percent1h = reader.readDecimal();
        percent24h = reader.readDecimal();
        percent7d = reader.readDecimal();
        percent30d = reader.readDecimal();
        percent60d = reader.readDecimal();
        percent90d = reader.readDecimal();
        marketCap = reader.readDecimal();
        dominance = reader.readDecimal();
        meta = Map<String, dynamic>.from(reader.readMap());
        break;
    }

    return MarketsModel(
      tid: tid,
      name: name,
      symbol: symbol,
      rank: rank,
      isInfinite: isInfinite,
      totalSupply: totalSupply,
      maxSupply: maxSupply,
      price: price,
      volume24h: volume24h,
      volumeChange24h: volumeChange24h,
      percent1h: percent1h,
      percent24h: percent24h,
      percent7d: percent7d,
      percent30d: percent30d,
      percent60d: percent60d,
      percent90d: percent90d,
      marketCap: marketCap,
      dominance: dominance,
      meta: meta,
    );
  }

  @override
  void write(BinaryWriter writer, MarketsModel obj) {
    writer.writeString(obj.tid);
    writer.writeString(obj.name);
    writer.writeString(obj.symbol);
    writer.writeInt(obj.rank);
    writer.writeBool(obj.isInfinite);
    writer.writeDecimal(obj.totalSupply ?? Decimal.zero);
    writer.writeDecimal(obj.maxSupply ?? Decimal.zero);
    writer.writeDecimal(obj.price ?? Decimal.zero);
    writer.writeDecimal(obj.volume24h ?? Decimal.zero);
    writer.writeDecimal(obj.volumeChange24h ?? Decimal.zero);
    writer.writeDecimal(obj.percent1h ?? Decimal.zero);
    writer.writeDecimal(obj.percent24h ?? Decimal.zero);
    writer.writeDecimal(obj.percent7d ?? Decimal.zero);
    writer.writeDecimal(obj.percent30d ?? Decimal.zero);
    writer.writeDecimal(obj.percent60d ?? Decimal.zero);
    writer.writeDecimal(obj.percent90d ?? Decimal.zero);
    writer.writeDecimal(obj.marketCap ?? Decimal.zero);
    writer.writeDecimal(obj.dominance ?? Decimal.zero);
    writer.writeMap(obj.meta);
  }
}
