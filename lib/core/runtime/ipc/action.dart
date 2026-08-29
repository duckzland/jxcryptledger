import 'dart:convert';
import 'dart:typed_data';

import '../../locator.dart';
import '../../../features/cryptos/service.dart';
import '../../../features/notification/service.dart';
import '../../../features/rates/service.dart';
import '../../../features/watchboard/markets/service.dart';
import '../../../features/watchboard/tickers/service.dart';

import '../../../ipc/abstracts/action.dart';
import '../../../ipc/status/op.dart';

class CoreRuntimeIpcAction extends IpcAction {
  const CoreRuntimeIpcAction({required super.database});

  @override
  Future<Uint8List> process(int op, String action, String key, Uint8List payload) async {
    final opName = IpcStatusOp.getName(op);
    switch (opName) {
      case "refreshRates":
        final service = CoreLocator.getit<RatesService>();
        await service.refreshRates();
        break;

      case "refreshCryptos":
        final service = CoreLocator.getit<CryptosService>();
        await service.fetch();
        break;

      case "refreshMarket":
        final service = CoreLocator.getit<MarketsService>();
        await service.refreshRates();
        break;

      case "refreshTickers":
        final service = CoreLocator.getit<TickersService>();
        await service.refreshRates();
        break;

      case "notification":
        final service = CoreLocator.getit<NotificationService>();
        final message = utf8.decode(payload);
        await service.show(message);
        break;

      case "addRateQueue":
        final parts = action.split("-");
        final sourceId = int.parse(parts[0]);
        final targetId = int.parse(parts[1]);
        final force = key == "true";
        final service = CoreLocator.getit<RatesService>();
        service.addQueue(sourceId, targetId, force: force);
        break;

      default:
        break;
    }

    return super.process(op, action, key, payload);
  }
}
