import '../core/runtime/locator.dart';
import '../system/settings/states.dart';

mixin MixinsState {
  final StateService states = locator<StateService>();
}
