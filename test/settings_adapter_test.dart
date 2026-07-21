import 'package:jxledger/ipc/protocol/reader.dart';
import 'package:jxledger/ipc/protocol/writer.dart';
import 'package:jxledger/system/settings/adapter.dart';
import 'package:jxledger/system/settings/keys.dart';
import 'package:jxledger/system/settings/model.dart';
import 'package:test/test.dart';

void main() {
  test('SettingsAdapter round-trips typed setting values', () {
    final adapter = SettingsAdapter();
    final writer = IpcWriter();
    final model = SettingsModel(keyId: SettingKey.vaultInitialized.id, type: SettingKey.vaultInitialized.type, value: 'ready');

    adapter.write(writer, model);

    final reader = IpcReader(writer.toBytes());
    final decoded = adapter.read(reader);

    expect(decoded, isA<SettingsModel>());
    expect(decoded.value, 'ready');
    expect(decoded.type, SettingType.string);
  });
}
