import '../core/locator.dart';
import '../system/settings/states.dart';

mixin MixinsState {
  StateController get states => CoreLocator.getit<StateController>();
}
