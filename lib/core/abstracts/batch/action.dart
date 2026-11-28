import '../exceptions.dart';

abstract class CoreBatchAction<T> {
  final T item;
  final Object? tag;

  String? id;
  Object? error;

  CoreBatchAction(this.item, {this.tag});

  bool get isSuccess => error == null && id != null;
  bool get isFailed => error != null;

  String get errorMessage => switch (error) {
    null => '',
    CoreBaseException e => e.userMessage,
    final e => e.toString(),
  };
}
