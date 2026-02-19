class SettingsModel {
  /// Generic key-value settings (JSON-like)
  final Map<String, dynamic> meta;

  const SettingsModel({required this.meta});

  Map<String, dynamic> toMap() {
    return {'meta': meta};
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(meta: Map<String, dynamic>.from(map['meta'] ?? {}));
  }

  SettingsModel copyWith({Map<String, dynamic>? meta}) {
    return SettingsModel(meta: meta ?? Map<String, dynamic>.from(this.meta));
  }
}
