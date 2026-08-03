typedef Validator = String? Function(String value);

enum SettingType { string, boolean, integer, list }

enum SettingKey {
  dataEndpoint(
    type: SettingType.string,
    isUserEditable: true,
    required: true,
    label: 'Cryptos Endpoint',
    defaultValue: "https://pro-api.coinmarketcap.com/public-api/v1/cryptocurrency/map",
    validator: _validateUrl,
    hintText: "https://example.com/public-api/v1/cryptocurrency/map",
  ),

  exchangeEndpoint(
    type: SettingType.string,
    isUserEditable: true,
    required: true,
    label: 'Exchange Endpoint',
    defaultValue: "https://pro-api.coinmarketcap.com/public-api/v2/tools/price-conversion",
    validator: _validateUrl,
    hintText: "https://example.com/public-api/v2/tools/price-conversion",
  ),

  altSeasonEndpoint(
    type: SettingType.string,
    isUserEditable: true,
    required: true,
    label: 'Alt Season Endpoint',
    defaultValue: "https://pro-api.coinmarketcap.com/public-api/v1/altcoin-season-index/latest",
    validator: _validateUrl,
    hintText: "https://example.com/public-api/v1/altcoin-season-index/latest",
  ),

  fearGreedEndpoint(
    type: SettingType.string,
    isUserEditable: true,
    required: true,
    label: 'Fear & Greed Endpoint',
    defaultValue: "https://pro-api.coinmarketcap.com/public-api/v3/fear-and-greed/latest",
    validator: _validateUrl,
    hintText: "https://example.com/public-api/v3/fear-and-greed/latest",
  ),

  cmc100Endpoint(
    type: SettingType.string,
    isUserEditable: true,
    required: true,
    label: 'CMC Top 100 Endpoint',
    defaultValue: "https://pro-api.coinmarketcap.com/public-api/v3/index/cmc100-latest",
    validator: _validateUrl,
    hintText: "https://example.com/public-api/v3/index/cmc100-latest",
  ),

  marketCapEndpoint(
    type: SettingType.string,
    isUserEditable: true,
    required: true,
    label: 'Market Cap Endpoint',
    defaultValue: "https://pro-api.coinmarketcap.com/public-api/v1/global-metrics/quotes/latest",
    validator: _validateUrl,
    hintText: "https://example.com/public-api/v1/global-metrics/quotes/latest",
  ),

  rsiEndpoint(
    type: SettingType.string,
    isUserEditable: true,
    required: true,
    label: 'RSI Endpoint',
    defaultValue: "https://api.coinmarketcap.com/data-api/v3/cryptocurrency/rsi/heatmap/overall",
    validator: _validateUrl,
    hintText: "https://example.com/data-api/v3/cryptocurrency/rsi/heatmap/overall",
  ),

  etfEndpoint(
    type: SettingType.string,
    isUserEditable: true,
    required: true,
    label: 'ETF Endpoint',
    defaultValue: "https://api.coinmarketcap.com/data-api/v3/etf/overview/netflow/chart",
    validator: _validateUrl,
    hintText: "https://example.com/data-api/v3/etf/overview/netflow/chart",
  ),

  dominanceEndpoint(
    type: SettingType.string,
    isUserEditable: true,
    required: true,
    label: 'Dominance Endpoint',
    defaultValue: "https://api.coinmarketcap.com/data-api/v3/global-metrics/dominance/overview",
    validator: _validateUrl,
    hintText: "https://example.com/data-api/v3/global-metrics/dominance/overview",
  ),

  marketEndpoint(
    type: SettingType.string,
    isUserEditable: true,
    required: true,
    label: 'Market Endpoint',
    defaultValue: "https://pro-api.coinmarketcap.com/public-api/v3/cryptocurrency/listings/latest",
    validator: _validateUrl,
    hintText: "https://example.com/public-api/v3/cryptocurrency/listings/latest",
  ),

  authorizationKey(
    type: SettingType.string,
    isUserEditable: true,
    required: false,
    label: 'Authorization Key',
    defaultValue: "",
    validator: null,
    hintText: "Will be added to the request authorization header",
  ),

  vaultInitialized(
    type: SettingType.string,
    isUserEditable: false,
    label: 'Vault Status',
    defaultValue: "",
    validator: null,
    hintText: "",
    required: true,
  ),

  states(
    type: SettingType.string,
    isUserEditable: false,
    label: 'App State',
    defaultValue: "{}",
    validator: null,
    hintText: "",
    required: false,
  ),

  migrateVersion(
    type: SettingType.string,
    isUserEditable: false,
    label: 'Migrate Version',
    defaultValue: "v1.1.0",
    validator: null,
    hintText: "",
    required: false,
  );

  final SettingType type;
  final bool isUserEditable;
  final String label;
  final String defaultValue;
  final Validator? validator;
  final String hintText;
  final bool required;

  const SettingKey({
    required this.type,
    required this.isUserEditable,
    required this.label,
    required this.defaultValue,
    required this.validator,
    required this.hintText,
    required this.required,
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
