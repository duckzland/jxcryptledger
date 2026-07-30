import '../../../app/exceptions.dart';
import '../../../core/abstracts/models/with_id.dart';

class MarketsModel implements CoreModelWithId {
  final String tid;
  final String name;
  final String symbol;
  final int rank;
  final bool isInfinite;
  final double? totalSupply;
  final double? maxSupply;
  final double? price;
  final double? volume24h;
  final double? volumeChange24h;
  final double? percent1h;
  final double? percent24h;
  final double? percent7d;
  final double? percent30d;
  final double? percent60d;
  final double? percent90d;
  final double? marketCap;
  final double? dominance;
  Map<String, dynamic> meta;

  @override
  String get uuid => tid;

  MarketsModel({
    required this.tid,
    required this.name,
    required this.symbol,
    required this.rank,
    required this.isInfinite,
    this.totalSupply,
    this.maxSupply,
    this.price,
    this.volume24h,
    this.volumeChange24h,
    this.percent1h,
    this.percent24h,
    this.percent7d,
    this.percent30d,
    this.percent60d,
    this.percent90d,
    this.marketCap,
    this.dominance,
    Map<String, dynamic>? meta,
  }) : meta = meta ?? {} {
    if (tid.isEmpty) {
      throw ValidationException(AppErrorCode.marketInvalidTid, "tid cannot be empty.", "Please enter a market ID.");
    }

    if (tid == '0') {
      throw ValidationException(AppErrorCode.marketInvalidTid, "tid cannot be '0'.", "This market ID is not allowed.");
    }

    if (name.isEmpty) {
      throw ValidationException(AppErrorCode.marketInvalidName, "name cannot be empty.", "Invalid market data.");
    }

    if (symbol.isEmpty) {
      throw ValidationException(AppErrorCode.marketInvalidSymbol, "symbol cannot be empty.", "Invalid market data.");
    }

    if (rank < 0) {
      throw ValidationException(AppErrorCode.marketInvalidRank, "rank must be >= 0.", "Invalid ranking.");
    }

    if (price != null && price! < 0) {
      throw ValidationException(AppErrorCode.marketInvalidNumeric, "price must be non-negative.", "Invalid market data.");
    }

    if (volume24h != null && volume24h! < 0) {
      throw ValidationException(AppErrorCode.marketInvalidNumeric, "volume24h must be non-negative.", "Invalid market data.");
    }

    if (marketCap != null && marketCap! < 0) {
      throw ValidationException(AppErrorCode.marketInvalidNumeric, "marketCap must be non-negative.", "Invalid market data.");
    }

    if (dominance != null && dominance! < 0) {
      throw ValidationException(AppErrorCode.marketInvalidNumeric, "dominance must be non-negative.", "Invalid market data.");
    }

    final percents = [percent1h, percent24h, percent7d, percent30d, percent60d, percent90d];
    if (percents.any((p) => p != null && p.isNaN)) {
      throw ValidationException(AppErrorCode.marketInvalidPercent, "percent values must be a valid number.", "Invalid percentage data.");
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'tid': tid,
      'name': name,
      'symbol': symbol,
      'rank': rank,
      'isInfinite': isInfinite,
      'totalSupply': totalSupply,
      'maxSupply': maxSupply,
      'price': price,
      'volume24h': volume24h,
      'volumeChange24h': volumeChange24h,
      'percent1h': percent1h,
      'percent24h': percent24h,
      'percent7d': percent7d,
      'percent30d': percent30d,
      'percent60d': percent60d,
      'percent90d': percent90d,
      'marketCap': marketCap,
      'dominance': dominance,
      'meta': meta,
    };
  }

  factory MarketsModel.fromMap(Map<String, dynamic> map) {
    return MarketsModel(
      tid: map['tid'] as String,
      name: map['name'] as String,
      symbol: map['symbol'] as String,
      rank: map['rank'] as int,
      isInfinite: map['isInfinite'] as bool,
      totalSupply: (map['totalSupply'] as num?)?.toDouble(),
      maxSupply: (map['maxSupply'] as num?)?.toDouble(),
      price: (map['price'] as num?)?.toDouble(),
      volume24h: (map['volume24h'] as num?)?.toDouble(),
      volumeChange24h: (map['volumeChange24h'] as num?)?.toDouble(),
      percent1h: (map['percent1h'] as num?)?.toDouble(),
      percent24h: (map['percent24h'] as num?)?.toDouble(),
      percent7d: (map['percent7d'] as num?)?.toDouble(),
      percent30d: (map['percent30d'] as num?)?.toDouble(),
      percent60d: (map['percent60d'] as num?)?.toDouble(),
      percent90d: (map['percent90d'] as num?)?.toDouble(),
      marketCap: (map['marketCap'] as num?)?.toDouble(),
      dominance: (map['dominance'] as num?)?.toDouble(),
      meta: map['meta'] != null ? Map<String, dynamic>.from(map['meta']) : {},
    );
  }

  MarketsModel copyWith({
    String? tid,
    String? name,
    String? symbol,
    int? rank,
    bool? isInfinite,
    double? totalSupply,
    double? maxSupply,
    double? price,
    double? volume24h,
    double? volumeChange24h,
    double? percent1h,
    double? percent24h,
    double? percent7d,
    double? percent30d,
    double? percent60d,
    double? percent90d,
    double? marketCap,
    double? dominance,
    Map<String, dynamic>? meta,
  }) {
    return MarketsModel(
      tid: tid ?? this.tid,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      rank: rank ?? this.rank,
      isInfinite: isInfinite ?? this.isInfinite,
      totalSupply: totalSupply ?? this.totalSupply,
      maxSupply: maxSupply ?? this.maxSupply,
      price: price ?? this.price,
      volume24h: volume24h ?? this.volume24h,
      volumeChange24h: volumeChange24h ?? this.volumeChange24h,
      percent1h: percent1h ?? this.percent1h,
      percent24h: percent24h ?? this.percent24h,
      percent7d: percent7d ?? this.percent7d,
      percent30d: percent30d ?? this.percent30d,
      percent60d: percent60d ?? this.percent60d,
      percent90d: percent90d ?? this.percent90d,
      marketCap: marketCap ?? this.marketCap,
      dominance: dominance ?? this.dominance,
      meta: meta ?? this.meta,
    );
  }
}
