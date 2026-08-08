import '../core/runtime/locators/client.dart';
import '../system/settings/states.dart';

mixin MixinsState {
  StateService get states => locator<StateService>();
}
