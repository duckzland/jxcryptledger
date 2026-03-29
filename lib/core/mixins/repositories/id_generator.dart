import 'dart:math';

import '../../abstracts/model.dart';
import '../../abstracts/repository.dart';

mixin CoreMixinsRepositoriesIdGenerator<T extends CoreBaseModel<K>, K> on CoreBaseRepository<T, K> {
  String generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();

    while (true) {
      final now = DateTime.now().microsecondsSinceEpoch;
      final timePart = now.toRadixString(36).padLeft(4, '0');
      final timeSuffix = timePart.substring(timePart.length - 4);
      final randomPart = String.fromCharCodes(Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length))));

      final id = '$timeSuffix$randomPart';
      if (!box.containsKey(id)) {
        return id;
      }
    }
  }
}
