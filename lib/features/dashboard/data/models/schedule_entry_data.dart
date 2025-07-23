class ScheduleEntryData {
  final String id;
  final String shiftName;
  final DateTime startTime;
  final DateTime endTime;

  ScheduleEntryData({
    required this.id,
    required this.shiftName,
    required this.startTime,
    required this.endTime,
  });

  factory ScheduleEntryData.fromMap(Map<String, dynamic> map, String id) {
    return ScheduleEntryData(
      id: id,
      shiftName: map['shiftName'] ?? '',
      startTime: DateTime.tryParse(map['startTime'] ?? '') ?? DateTime.now(),
      endTime: DateTime.tryParse(map['endTime'] ?? '') ?? DateTime.now(),
    );
  }
}
