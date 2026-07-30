import 'dart:convert';
import '../model.dart';

List<MarketsModel> parseMarketsV3(String body) {
  final Map<String, dynamic> jsonBody = json.decode(body) as Map<String, dynamic>;
  final List<dynamic> dataList = jsonBody['data'];
  final List<MarketsModel> markets = [];

  for (final item in dataList) {
    final quote = (item['quote'] as List).firstWhere((q) => q['symbol'] == 'USD', orElse: () => null);

    if (quote == null) continue;

    markets.add(
      MarketsModel(
        tid: item['id'].toString(),
        name: item['name'] as String,
        symbol: item['symbol'] as String,
        rank: item['cmc_rank'] as int,
        isInfinite: item['infinite_supply'] as bool,
        totalSupply: (item['total_supply'] as num?)?.toDouble(),
        maxSupply: (item['max_supply'] as num?)?.toDouble(),
        price: (quote['price'] as num?)?.toDouble(),
        volume24h: (quote['volume_24h'] as num?)?.toDouble(),
        volumeChange24h: (quote['volume_change_24h'] as num?)?.toDouble(),
        percent1h: (quote['percent_change_1h'] as num?)?.toDouble(),
        percent24h: (quote['percent_change_24h'] as num?)?.toDouble(),
        percent7d: (quote['percent_change_7d'] as num?)?.toDouble(),
        percent30d: (quote['percent_change_30d'] as num?)?.toDouble(),
        percent60d: (quote['percent_change_60d'] as num?)?.toDouble(),
        percent90d: (quote['percent_change_90d'] as num?)?.toDouble(),
        marketCap: (quote['market_cap'] as num?)?.toDouble(),
        dominance: (quote['market_cap_dominance'] as num?)?.toDouble(),
        meta: {
          'slug': item['slug'],
          'tags': item['tags'],
          'date_added': item['date_added'],
          'last_updated': item['last_updated'],
          'num_market_pairs': item['num_market_pairs'],
        },
      ),
    );
  }

  markets.sort((a, b) => a.rank.compareTo(b.rank));
  return markets;
}
