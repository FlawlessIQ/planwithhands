/// Utility functions for Firestore document ID generation
library;

String generateFirestoreId(String collection, String baseName) {
  // Slugify baseName: lowercase, replace non-alphanumeric with hyphens, collapse hyphens
  // Slugify baseName: lowercase, replace non-alphanumeric with hyphens, collapse hyphens, trim hyphens
  final slugifiedBaseName = baseName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+|-+ '), '');
  // Generate UTC timestamp in YYYYMMDDHHmmss
  final now = DateTime.now().toUtc();
  final timestamp =
      now.year.toString().padLeft(4, '0') +
      now.month.toString().padLeft(2, '0') +
      now.day.toString().padLeft(2, '0') +
      now.hour.toString().padLeft(2, '0') +
      now.minute.toString().padLeft(2, '0') +
      now.second.toString().padLeft(2, '0');
  return '${collection.toLowerCase()}_${slugifiedBaseName}_$timestamp';
}
