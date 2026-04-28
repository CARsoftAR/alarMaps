import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SelectedAlarm {
  final String title;
  final String uri;
  final bool isAsset;

  SelectedAlarm({
    required this.title,
    required this.uri,
    this.isAsset = false,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'uri': uri,
    'isAsset': isAsset,
  };

  factory SelectedAlarm.fromJson(Map<String, dynamic> json) => SelectedAlarm(
    title: json['title'],
    uri: json['uri'],
    isAsset: json['isAsset'] ?? false,
  );

  static SelectedAlarm defaultAlarm() => SelectedAlarm(
    title: 'Alarma Estándar',
    uri: 'alarm.mp3',
    isAsset: true,
  );
}

final selectedAlarmProvider = StateNotifierProvider<AlarmNotifier, SelectedAlarm>((ref) {
  return AlarmNotifier();
});

class AlarmNotifier extends StateNotifier<SelectedAlarm> {
  AlarmNotifier() : super(SelectedAlarm.defaultAlarm()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('selected_alarm_json');
    if (data != null) {
      try {
        state = SelectedAlarm.fromJson(jsonDecode(data));
      } catch (e) {
        state = SelectedAlarm.defaultAlarm();
      }
    }
  }

  Future<void> setAlarm(SelectedAlarm alarm) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_alarm_json', jsonEncode(alarm.toJson()));
    state = alarm;
  }
}
