import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/active_focus_timer.dart';
import '../domain/repositories/focus_timer_gateways.dart';
import 'active_focus_timer_codec.dart';

class SharedPreferencesFocusTimerStore implements ActiveFocusTimerStore {
  SharedPreferencesFocusTimerStore(
    this._preferences, {
    this.codec = const ActiveFocusTimerCodec(),
  });

  static const _key = 'active_focus_timer_v1';
  final SharedPreferencesAsync _preferences;
  final ActiveFocusTimerCodec codec;

  @override
  Future<ActiveFocusTimer?> load() async {
    final value = await _preferences.getString(_key);
    return value == null ? null : codec.decode(value);
  }

  @override
  Future<void> save(ActiveFocusTimer timer) =>
      _preferences.setString(_key, codec.encode(timer));

  @override
  Future<void> clear() => _preferences.remove(_key);
}
