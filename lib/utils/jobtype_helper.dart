// Helper to coerce jobType / jobTypes fields into a List<String>
List<String> coerceToJobTypes(dynamic raw) {
  if (raw == null) return [];
  try {
    if (raw is String) return [raw];
    if (raw is List) return List<String>.from(raw.map((e) => e.toString()));
    // Fallback: single value of another type
    return [raw.toString()];
  } catch (_) {
    return [];
  }
}
