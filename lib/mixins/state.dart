import '../core/runtime/locator.dart';
import '../system/settings/states.dart';

mixin MixinsState {
  StateService get states => locator<StateService>();
}
