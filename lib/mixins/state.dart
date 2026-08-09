import '../core/runtime/locators/client.dart';
import '../system/settings/states.dart';

mixin MixinsState {
  StateController get states => locator<StateController>();
}
