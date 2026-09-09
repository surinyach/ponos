import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/repositories/focus_timer_gateways.dart';

class LocalFocusTimerNotificationScheduler
    implements FocusTimerNotificationScheduler {
  LocalFocusTimerNotificationScheduler({
    FlutterLocalNotificationsPlugin? plugin,
    DateTime Function()? clock,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _clock = clock ?? DateTime.now;

  static const _focusId = 41001;
  static const _restId = 41002;
  final FlutterLocalNotificationsPlugin _plugin;
  final DateTime Function() _clock;
  final AudioPlayer _webAlarmPlayer = AudioPlayer();
  final Map<FocusTimerAlert, Timer> _webTimers = {};
  Future<void>? _initialization;

  @override
  Future<void> requestPermissions() async {
    await _ensureInitialized();
    if (kIsWeb) {
      try {
        await _webAlarmPlayer.play(_alarmSource, volume: 0);
        await _webAlarmPlayer.stop();
      } catch (_) {
        // Notification permission should still be requested if audio is blocked.
      }
      await _plugin
          .resolvePlatformSpecificImplementation<
            WebFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await android?.requestNotificationsPermission();
        await android?.requestExactAlarmsPermission();
      case TargetPlatform.iOS:
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true);
      case TargetPlatform.macOS:
        await _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true);
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.fuchsia:
        break;
    }
  }

  @override
  Future<void> schedule(FocusTimerAlert alert, DateTime scheduledAt) async {
    await _ensureInitialized();
    await cancel(alert);
    if (kIsWeb) {
      final delay = scheduledAt.difference(_clock());
      if (delay <= Duration.zero) {
        await _show(alert);
      } else {
        _webTimers[alert] = Timer(delay, () {
          _webTimers.remove(alert);
          unawaited(_show(alert));
        });
      }
      return;
    }
    if (!scheduledAt.isAfter(_clock())) {
      await _show(alert);
      return;
    }
    final scheduleMode = defaultTargetPlatform == TargetPlatform.android
        ? (await _plugin
                      .resolvePlatformSpecificImplementation<
                        AndroidFlutterLocalNotificationsPlugin
                      >()
                      ?.canScheduleExactNotifications() ??
                  false
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle)
        : AndroidScheduleMode.inexactAllowWhileIdle;
    await _plugin.zonedSchedule(
      id: _id(alert),
      title: _title(alert),
      body: _body(alert),
      scheduledDate: tz.TZDateTime.from(scheduledAt.toUtc(), tz.UTC),
      notificationDetails: _details,
      androidScheduleMode: scheduleMode,
      payload: alert.name,
    );
  }

  @override
  Future<void> cancel(FocusTimerAlert alert) async {
    _webTimers.remove(alert)?.cancel();
    await _ensureInitialized();
    await _plugin.cancel(id: _id(alert));
  }

  @override
  Future<void> cancelAll() async {
    for (final timer in _webTimers.values) {
      timer.cancel();
    }
    _webTimers.clear();
    await _ensureInitialized();
    await _plugin.cancel(id: _focusId);
    await _plugin.cancel(id: _restId);
  }

  Future<void> _ensureInitialized() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
        web: WebInitializationSettings(),
      ),
    );
  }

  Future<void> _show(FocusTimerAlert alert) async {
    await Future.wait([
      _plugin.show(
        id: _id(alert),
        title: _title(alert),
        body: _body(alert),
        notificationDetails: _details,
        payload: alert.name,
      ),
      if (kIsWeb) _webAlarmPlayer.play(_alarmSource, volume: 1),
    ]);
  }

  int _id(FocusTimerAlert alert) => switch (alert) {
    FocusTimerAlert.focusComplete => _focusId,
    FocusTimerAlert.restComplete => _restId,
  };

  String _title(FocusTimerAlert alert) => switch (alert) {
    FocusTimerAlert.focusComplete => 'Focus complete',
    FocusTimerAlert.restComplete => 'Execution complete',
  };

  String _body(FocusTimerAlert alert) => switch (alert) {
    FocusTimerAlert.focusComplete => 'Time to rest.',
    FocusTimerAlert.restComplete => 'Your rest is complete.',
  };

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'focus_timer_alarms',
      'Focus timer alarms',
      channelDescription: 'Alerts when focus and rest phases finish',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    macOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
  );

  static final _alarmSource = BytesSource(
    _createAlarmWave(),
    mimeType: 'audio/wav',
  );

  static Uint8List _createAlarmWave() {
    const sampleRate = 8000;
    const durationMilliseconds = 650;
    final sampleCount = sampleRate * durationMilliseconds ~/ 1000;
    final bytes = ByteData(44 + sampleCount * 2);

    void text(int offset, String value) {
      for (var index = 0; index < value.length; index++) {
        bytes.setUint8(offset + index, value.codeUnitAt(index));
      }
    }

    text(0, 'RIFF');
    bytes.setUint32(4, 36 + sampleCount * 2, Endian.little);
    text(8, 'WAVEfmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    text(36, 'data');
    bytes.setUint32(40, sampleCount * 2, Endian.little);
    for (var index = 0; index < sampleCount; index++) {
      final milliseconds = index * 1000 ~/ sampleRate;
      final audible = milliseconds < 250 || milliseconds >= 400;
      final sample = audible
          ? (math.sin(2 * math.pi * 880 * index / sampleRate) * 18000).round()
          : 0;
      bytes.setInt16(44 + index * 2, sample, Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}
