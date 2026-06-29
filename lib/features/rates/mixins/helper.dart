import '../../../app/exceptions.dart';
import '../../../core/runtime/locator.dart';
import '../../cryptos/repository.dart';

mixin RatesMixinsHelper {
  CryptosRepository get cryptosRepo => locator<CryptosRepository>();

  bool isValidPair(int sourceId, int targetId) {
    if (sourceId == 0 || targetId == 0) return false;
    if (cryptosRepo.isEmpty()) return false;
    if (sourceId == targetId) return false;

    final ids = cryptosRepo.extract().map((c) => c.uuid).toSet();
    return ids.contains(sourceId) && ids.contains(targetId);
  }

  void validateIds(int sourceId, int targetId) {
    if (!isValidPair(sourceId, targetId)) {
      throw NetworkingException(
        AppErrorCode.netInvalidRatePayload,
        'Invalid rate pair: $sourceId -> $targetId',
        "One of the selected cryptocurrencies is not valid.",
      );
    }
  }
}
