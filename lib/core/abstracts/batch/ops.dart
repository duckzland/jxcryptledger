import '../../../app/exceptions.dart';
import 'action.dart';

abstract class CoreBatchOps<T, A extends CoreBatchAction<T>> {
  final List<A> actions = [];

  int get length => actions.length;

  bool get isEmpty => actions.isEmpty;
  bool get isNotEmpty => actions.isNotEmpty;

  bool get isAllSuccess => actions.every((a) => a.isSuccess);
  bool get hasFailures => actions.any((a) => a.isFailed);

  List<A> get succeeded => actions.where((a) => a.isSuccess).toList();
  List<A> get failed => actions.where((a) => a.isFailed).toList();

  List<T> get failedItems => failed.map((a) => a.item).toList();
  List<String> get failedMessages => failed.map((a) => a.errorMessage).toList();

  String get firstErrorMessage => failedMessages.firstOrNull ?? '';

  List<Tag> succeededTags<Tag>() {
    final grouped = <Tag, List<A>>{};
    for (final a in actions) {
      if (a.tag is Tag) {
        (grouped[a.tag as Tag] ??= []).add(a);
      }
    }
    return grouped.entries.where((e) => e.value.every((a) => a.isSuccess)).map((e) => e.key).toList();
  }

  BatchException toException(dynamic code, String userMessage) =>
      BatchException(code, "Batch ops failed: ${failed.length}/$length failed. ${failedMessages.join('; ')}", userMessage);
}
