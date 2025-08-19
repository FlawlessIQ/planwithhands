// Utility to coerce Firestore location fields into a canonical List<String>
List<String> coerceToLocationIds(dynamic value) {
  if (value == null) return [];

  // If it's already a single String, return as single-item list
  if (value is String) return [value];

  // If it's an iterable (List, etc), try to convert each item to string
  if (value is Iterable) {
    try {
      return value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  // Fallback: attempt to stringify
  try {
    final s = value.toString();
    return s.isNotEmpty ? [s] : [];
  } catch (_) {
    return [];
  }
}
