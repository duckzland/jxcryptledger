typedef Validator = String? Function(String value);

enum SettingType { string, boolean, integer, list }

enum SettingKey {
  dataEndpoint(
    type: SettingType.string,
    isUserEditable: true,
    label: 'Cryptos Endpoint',
    defaultValue: "https://s3.coinmarketcap.com/generated/core/crypto/cryptos.json",
    validator: _validateUrl,
    hintText: "https://example.com/cryptos.json",
  ),

  exchangeEndpoint(
    type: SettingType.string,
    isUserEditable: true,
    label: 'Exchange Endpoint',
    defaultValue: "https://api.coinmarketcap.com/data-api/v3/tools/price-conversion",
    validator: _validateUrl,
    hintText: "https://example.com/exchange",
  ),

  altSeasonEndpoint(
    type: SettingType.string,
    isUserEditable: true,
    label: 'Alt Season Endpoint',
    defaultValue: "https://api.coinmarketcap.com/data-api/v3/altcoin-season/chart",
    validator: _validateUrl,
    hintText: "https://example.com/altseason",
  ),

  fearGreedEndpoint(
    type: SettingType.string,
    isUserEditable: true,
    label: 'Fear & Greed Endpoint',
    defaultValue: "https://api.coinmarketcap.com/data-api/v3/fear-greed/chart",
    validator: _validateUrl,
    hintText: "https://example.com/feargreed",
  ),

  cmc100Endpoint(
    type: SettingType.string,
    isUserEditable: true,
    label: 'CMC Top 100 Endpoint',
    defaultValue: "https://api.coinmarketcap.com/data-api/v3/top100/supplement",
    validator: _validateUrl,
    hintText: "https://example.com/top100",
  ),

  marketCapEndpoint(
    type: SettingType.string,
    isUserEditable: true,
    label: 'Market Cap Endpoint',
    defaultValue: "https://api.coinmarketcap.com/data-api/v4/global-metrics/quotes/historical",
    validator: _validateUrl,
    hintText: "https://example.com/marketcap",
  ),

  rsiEndpoint(
    type: SettingType.string,
    isUserEditable: true,
    label: 'RSI Endpoint',
    defaultValue: "https://api.coinmarketcap.com/data-api/v3/cryptocurrency/rsi/heatmap/overall",
    validator: _validateUrl,
    hintText: "https://example.com/rsi",
  ),

  etfEndpoint(
    type: SettingType.string,
    isUserEditable: true,
    label: 'ETF Endpoint',
    defaultValue: "https://api.coinmarketcap.com/data-api/v3/etf/overview/netflow/chart",
    validator: _validateUrl,
    hintText: "https://example.com/etf",
  ),

  dominanceEndpoint(
    type: SettingType.string,
    isUserEditable: true,
    label: 'Dominance Endpoint',
    defaultValue: "https://api.coinmarketcap.com/data-api/v3/global-metrics/dominance/overview",
    validator: _validateUrl,
    hintText: "https://example.com/dominance",
  ),

  authorizationKey(
    type: SettingType.string,
    isUserEditable: true,
    label: 'Authorization Key',
    defaultValue: "",
    validator: null,
    hintText: "Will be added to the request authorization header",
  ),

  vaultInitialized(type: SettingType.string, isUserEditable: false, label: 'Vault Status', defaultValue: "", validator: null, hintText: "");

  final SettingType type;
  final bool isUserEditable;
  final String label;
  final String defaultValue;
  final Validator? validator;
  final String hintText;

  const SettingKey({
    required this.type,
    required this.isUserEditable,
    required this.label,
    required this.defaultValue,
    required this.validator,
    required this.hintText,
  });

  String get id => name;
}

String? _validateUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
    return "Invalid URL";
  }
  return null;
}
