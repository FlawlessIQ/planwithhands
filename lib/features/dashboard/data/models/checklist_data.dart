class ChecklistData {
  final String id;
  final String title;
  final bool photoRequired;

  ChecklistData({
    required this.id,
    required this.title,
    required this.photoRequired,
  });

  factory ChecklistData.fromMap(Map<String, dynamic> map, String id) {
    return ChecklistData(
      id: id,
      title: map['title'] ?? '',
      photoRequired: map['photoRequired'] ?? false,
    );
  }
}
