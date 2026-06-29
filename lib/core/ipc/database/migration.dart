import '../../../app/constants.dart';
import '../../../features/watchboard/tickers/service.dart';
import '../../runtime/locator.dart';

class CoreIpcMigration {
  final TickersService _tickersService = locator<TickersService>();

  Future<void> migrate() async {
    if (isVersionLessThan(appVersion, "1.3.0.0")) {
      final tickers = _tickersService.extract();
      final exists = tickers.any((ticker) => ticker.tid == "market_cap");
      if (!exists) {
        await _tickersService.clear();
        await _tickersService.populate();
      }
    }
  }

  bool isVersionLessThan(String current, String target) {
    final currentParts = current.split('.').map(int.parse).toList();
    final targetParts = target.split('.').map(int.parse).toList();

    for (int i = 0; i < currentParts.length; i++) {
      if (currentParts[i] < targetParts[i]) return true;
      if (currentParts[i] > targetParts[i]) return false;
    }
    return false;
  }
}
