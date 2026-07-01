import 'package:jxledger/core/ipc/protocol/reader.dart';
import 'package:jxledger/core/ipc/protocol/writer.dart';
import 'package:jxledger/features/settings/adapter.dart';
import 'package:jxledger/features/settings/keys.dart';
import 'package:jxledger/features/settings/model.dart';
import 'package:test/test.dart';

void main() {
  test('SettingsAdapter round-trips typed setting values', () {
    final adapter = SettingsAdapter();
    final writer = CoreIpcWriter();
    final model = SettingsModel(keyId: SettingKey.vaultInitialized.id, type: SettingKey.vaultInitialized.type, value: 'ready');

    adapter.write(writer, model);

    final reader = CoreIpcReader(writer.toBytes());
    final decoded = adapter.read(reader);

    expect(decoded, isA<SettingsModel>());
    expect(decoded.value, 'ready');
    expect(decoded.type, SettingType.string);
  });

  test('SettingsModel.fromLegacy converts old map payloads', () {
    final migrated = SettingsModel.fromLegacy('vaultInitialized', {'vaultInitialized': 'initialized'});

    expect(migrated.keyId, 'vaultInitialized');
    expect(migrated.value, 'initialized');
    expect(migrated.type, SettingType.string);
  });
}
