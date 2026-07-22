import 'package:flutter_test/flutter_test.dart';
import 'package:hands_app/utils/localized_content.dart';
import 'package:intl/intl.dart';

void main() {
  group('localizedContent', () {
    test('prefers translations map for the current locale', () {
      Intl.defaultLocale = 'es';

      final value = localizedContent(
        {
          'name': 'Opening Checklist',
          'translations': {
            'es': {'name': 'Lista de apertura'},
          },
        },
        fieldKeys: const ['name'],
      );

      expect(value, 'Lista de apertura');
    });

    test('supports fieldByLanguage maps', () {
      Intl.defaultLocale = 'es';

      final value = localizedContent(
        {
          'taskName': 'Clean soda gun',
          'taskNameByLanguage': {'es': 'Limpiar la pistola de refrescos'},
        },
        fieldKeys: const ['taskName'],
      );

      expect(value, 'Limpiar la pistola de refrescos');
    });

    test('falls back to base field when no localized value exists', () {
      Intl.defaultLocale = 'es';

      final value = localizedContent(
        {'description': 'Check the walk-in cooler'},
        fieldKeys: const ['description'],
      );

      expect(value, 'Check the walk-in cooler');
    });

    test('matches region-specific translation keys', () {
      Intl.defaultLocale = 'es-MX';

      final value = localizedContent(
        {
          'name': 'Shift',
          'translations': {
            'es_MX': {'name': 'Turno'},
          },
        },
        fieldKeys: const ['name'],
      );

      expect(value, 'Turno');
    });

    test('falls back from pt-BR locale to base pt translation', () {
      Intl.defaultLocale = 'pt-BR';

      final value = localizedContent(
        {
          'name': 'Opening Checklist',
          'translations': {
            'pt': {'name': 'Checklist de abertura'},
          },
        },
        fieldKeys: const ['name'],
      );

      expect(value, 'Checklist de abertura');
    });

    test('supports pt fieldByLanguage values for worker task content', () {
      Intl.defaultLocale = 'pt';

      final value = localizedContent(
        {
          'taskName': 'Check fryer oil',
          'taskNameByLanguage': {'pt': 'Verificar o oleo da fritadeira'},
        },
        fieldKeys: const ['taskName'],
      );

      expect(value, 'Verificar o oleo da fritadeira');
    });
  });
}
