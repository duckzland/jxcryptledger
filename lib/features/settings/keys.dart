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
