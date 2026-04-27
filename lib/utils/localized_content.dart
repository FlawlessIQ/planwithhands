import 'package:intl/intl.dart';

Map<String, dynamic>? _asStringMap(dynamic value) {
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }
  return null;
}

List<String> _localeCandidates(String? localeCode) {
  final raw = (localeCode ?? Intl.getCurrentLocale()).trim();
  if (raw.isEmpty) {
    return const ['en'];
  }

  final hyphen = raw.replaceAll('_', '-');
  final parts = hyphen.split('-').where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) {
    return const ['en'];
  }

  final language = parts.first.toLowerCase();
  final region = parts.length > 1 ? parts[1].toUpperCase() : null;
  final candidates = <String>[
    if (region != null) '${language}_$region',
    if (region != null) '$language-$region',
    language,
  ];

  return candidates.toSet().toList();
}

String? _readLocalizedValue(
  Map<String, dynamic> source,
  String fieldKey,
  List<String> localeCandidates,
) {
  final byLanguage = _asStringMap(source['${fieldKey}ByLanguage']);
  if (byLanguage != null) {
    for (final localeKey in localeCandidates) {
      final value = byLanguage[localeKey]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
  }

  final translations = _asStringMap(source['translations']);
  if (translations != null) {
    for (final localeKey in localeCandidates) {
      final localizedMap = _asStringMap(translations[localeKey]);
      final value = localizedMap?[fieldKey]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
  }

  return null;
}

String? localizedContentOrNull(
  Map<String, dynamic> source, {
  required List<String> fieldKeys,
  String? localeCode,
}) {
  final localeCandidates = _localeCandidates(localeCode);

  for (final fieldKey in fieldKeys) {
    final localized = _readLocalizedValue(source, fieldKey, localeCandidates);
    if (localized != null && localized.isNotEmpty) {
      return localized;
    }
  }

  for (final fieldKey in fieldKeys) {
    final value = source[fieldKey]?.toString().trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return null;
}

String localizedContent(
  Map<String, dynamic> source, {
  required List<String> fieldKeys,
  String? localeCode,
  String fallback = '',
}) {
  return localizedContentOrNull(
        source,
        fieldKeys: fieldKeys,
        localeCode: localeCode,
      ) ??
      fallback;
}
