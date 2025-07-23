import 'package:flutter/material.dart';

TimeOfDay convertDateTimeToTimeOfDay(DateTime dateTime) {
  return TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
}

DateTime convertTimeOfDayToDateTime(TimeOfDay timeOfDay, {DateTime? baseDate}) {
  final now = baseDate ?? DateTime.now();
  return DateTime(
    now.year,
    now.month,
    now.day,
    timeOfDay.hour,
    timeOfDay.minute,
  );
}
