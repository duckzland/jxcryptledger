class CryptosModel {
  final int id;
  final String name;
  final String symbol;
  final int status;
  final int active;

  const CryptosModel({
    required this.id,
    required this.name,
    required this.symbol,
    required this.status,
    required this.active,
  });

  /// Normalized search key for Hive lookups
  String get searchKey => '$symbol $name $id'.toLowerCase();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'symbol': symbol,
      'status': status,
      'active': active,
      'searchKey': searchKey,
    };
  }

  factory CryptosModel.fromMap(Map<String, dynamic> map) {
    return CryptosModel(
      id: map['id'] as int,
      name: map['name'] as String,
      symbol: map['symbol'] as String,
      status: map['status'] as int,
      active: map['active'] as int,
    );
  }

  CryptosModel copyWith({
    int? id,
    String? name,
    String? symbol,
    int? status,
    int? active,
  }) {
    return CryptosModel(
      id: id ?? this.id,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      status: status ?? this.status,
      active: active ?? this.active,
    );
  }
}
