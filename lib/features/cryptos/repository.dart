import '../../core/abstracts/repository.dart';
import '../../core/mixins/repositories/filterable.dart';
import 'model.dart';

class CryptosRepository extends CoreBaseRepository<CryptosModel, int> with CoreMixinsRepositoriesFilterable<CryptosModel, int> {
  @override
  String get boxName => 'cryptos_box';

  Map<int, String>? _symbolCache;

  @override
  void onAction() {
    _symbolCache = null;
  }

  String? getSymbol(int id) {
    return getSymbolMap()[id];
  }

  Map<int, String> getSymbolMap() {
    if (_symbolCache != null) return _symbolCache!;
    final all = box.values.cast<CryptosModel>();
    return {for (var c in all) c.uuid: c.symbol};
  }
}
