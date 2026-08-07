import 'package:decimal/decimal.dart';

import '../../../app/exceptions.dart';
import '../../../core/abstracts/models/with_id.dart';
import '../../../core/utils.dart';

class MarketsModel implements CoreModelWithId {
  final String tid;
  final String name;
  final String symbol;
  final int rank;
  final bool isInfinite;
  final Decimal? totalSupply;
  final Decimal? maxSupply;
  final Decimal? price;
  final Decimal? volume24h;
  final Decimal? volumeChange24h;
  final Decimal? percent1h;
  final Decimal? percent24h;
  final Decimal? percent7d;
  final Decimal? percent30d;
  final Decimal? percent60d;
  final Decimal? percent90d;
  final Decimal? marketCap;
  final Decimal? dominance;
  final Map<String, dynamic> meta;

  final String _rankText;
  final String _priceText;
  final String _percent1hText;
  final String _percent24hText;
  final String _percent7dText;
  final String _percent30dText;
  final String _percent60dText;
  final String _percent90dText;
  final String _marketCapText;
  final String _dominanceText;

  final List<String> _tags;
  bool? _isStableCoin;

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
  }) : meta = meta ?? {},
       _rankText = rank.toString(),
       _priceText = Utils.formatSmartDecimal(price ?? Decimal.zero),
       _percent1hText = Utils.formatSmartDecimal(percent1h ?? Decimal.zero, maxDecimals: 2, smartDecimal: false),
       _percent24hText = Utils.formatSmartDecimal(percent24h ?? Decimal.zero, maxDecimals: 2, smartDecimal: false),
       _percent7dText = Utils.formatSmartDecimal(percent7d ?? Decimal.zero, maxDecimals: 2, smartDecimal: false),
       _percent30dText = Utils.formatSmartDecimal(percent30d ?? Decimal.zero, maxDecimals: 2, smartDecimal: false),
       _percent60dText = Utils.formatSmartDecimal(percent60d ?? Decimal.zero, maxDecimals: 2, smartDecimal: false),
       _percent90dText = Utils.formatSmartDecimal(percent90d ?? Decimal.zero, maxDecimals: 2, smartDecimal: false),
       _marketCapText = Utils.formatShortCurrency(marketCap ?? Decimal.zero),
       _dominanceText = Utils.formatSmartDecimal(dominance ?? Decimal.zero, maxDecimals: 2),
       _tags = ((meta?['tags'] as List?)?.map((t) => t.toString().toLowerCase()).toList() ?? const []) {
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
    if (price != null && price! < Decimal.zero) {
      throw ValidationException(AppErrorCode.marketInvalidNumeric, "price must be non-negative.", "Invalid market data.");
    }
    if (volume24h != null && volume24h! < Decimal.zero) {
      throw ValidationException(AppErrorCode.marketInvalidNumeric, "volume24h must be non-negative.", "Invalid market data.");
    }
    if (marketCap != null && marketCap! < Decimal.zero) {
      throw ValidationException(AppErrorCode.marketInvalidNumeric, "marketCap must be non-negative.", "Invalid market data.");
    }
    if (dominance != null && dominance! < Decimal.zero) {
      throw ValidationException(AppErrorCode.marketInvalidNumeric, "dominance must be non-negative.", "Invalid market data.");
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
      totalSupply: map['totalSupply'] as Decimal?,
      maxSupply: map['maxSupply'] as Decimal?,
      price: map['price'] as Decimal?,
      volume24h: map['volume24h'] as Decimal?,
      volumeChange24h: map['volumeChange24h'] as Decimal?,
      percent1h: map['percent1h'] as Decimal?,
      percent24h: map['percent24h'] as Decimal?,
      percent7d: map['percent7d'] as Decimal?,
      percent30d: map['percent30d'] as Decimal?,
      percent60d: map['percent60d'] as Decimal?,
      percent90d: map['percent90d'] as Decimal?,
      marketCap: map['marketCap'] as Decimal?,
      dominance: map['dominance'] as Decimal?,
      meta: map['meta'] != null ? Map<String, dynamic>.from(map['meta']) : {},
    );
  }

  MarketsModel copyWith({
    String? tid,
    String? name,
    String? symbol,
    int? rank,
    bool? isInfinite,
    Decimal? totalSupply,
    Decimal? maxSupply,
    Decimal? price,
    Decimal? volume24h,
    Decimal? volumeChange24h,
    Decimal? percent1h,
    Decimal? percent24h,
    Decimal? percent7d,
    Decimal? percent30d,
    Decimal? percent60d,
    Decimal? percent90d,
    Decimal? marketCap,
    Decimal? dominance,
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

  bool _checkIsStableCoin(String symbol, Map<String, dynamic> meta) {
    final tags = (meta['tags'] as List?)?.map((t) => t.toString().toLowerCase()).toList() ?? const [];
    if (tags.contains('stablecoin')) return true;

    const stablecoins = {
      'usdt',
      'usdc',
      'dai',
      'fdusd',
      'usde',
      'tusd',
      'busd',
      'pyusd',
      'usdd',
      'frax',
      'usdg',
      'gho',
      'lusd',
      'crvusd',
      'rlusd',
      'usd1',
      'usdy',
      'u',
    };
    return stablecoins.contains(symbol.toLowerCase());
  }

  String get rankText => _rankText;
  String get priceText => _priceText;
  String get percent1hText => _percent1hText;
  String get percent24hText => _percent24hText;
  String get percent7dText => _percent7dText;
  String get percent30dText => _percent30dText;
  String get percent60dText => _percent60dText;
  String get percent90dText => _percent90dText;
  String get marketCapText => _marketCapText;
  String get dominanceText => _dominanceText;

  List<String> get tags => _tags;

  bool get isStableCoin {
    _isStableCoin ??= _checkIsStableCoin(symbol, meta);
    return _isStableCoin!;
  }
}
