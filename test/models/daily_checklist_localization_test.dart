import 'package:flutter_test/flutter_test.dart';
import 'package:hands_app/models/daily_checklist.dart';
import 'package:intl/intl.dart';

void main() {
  group('DailyChecklist localization fallback', () {
    test('DailyChecklistTask.fromMap reads translated task labels', () {
      Intl.defaultLocale = 'es';

      final task = DailyChecklistTask.fromMap({
        'taskId': 'task-1',
        'taskName': 'Clean soda gun',
        'translations': {
          'es': {'taskName': 'Limpiar la pistola de refrescos'},
        },
      });

      expect(task.description, 'Limpiar la pistola de refrescos');
    });

    test('DailyChecklist.fromMap reads translated template name', () {
      Intl.defaultLocale = 'es';

      final checklist = DailyChecklist.fromMap({
        'checklistTemplateId': 'template-1',
        'shiftId': 'shift-1',
        'locationId': 'location-1',
        'organizationId': 'org-1',
        'date': '2026-04-25',
        'createdAt': '2026-04-25T00:00:00.000Z',
        'updatedAt': '2026-04-25T00:00:00.000Z',
        'templateName': 'Opening Checklist',
        'translations': {
          'es': {'templateName': 'Lista de apertura'},
        },
        'tasks': const [],
      }, 'checklist-1');

      expect(checklist.templateName, 'Lista de apertura');
    });

    test('DailyChecklistTask.fromMap reads Portuguese task labels', () {
      Intl.defaultLocale = 'pt-BR';

      final task = DailyChecklistTask.fromMap({
        'taskId': 'task-2',
        'taskName': 'Clean soda gun',
        'translations': {
          'pt': {'taskName': 'Limpar a pistola de refrigerante'},
        },
      });

      expect(task.description, 'Limpar a pistola de refrigerante');
    });

    test('DailyChecklist.fromMap reads Portuguese template name', () {
      Intl.defaultLocale = 'pt';

      final checklist = DailyChecklist.fromMap({
        'checklistTemplateId': 'template-2',
        'shiftId': 'shift-1',
        'locationId': 'location-1',
        'organizationId': 'org-1',
        'date': '2026-04-25',
        'createdAt': '2026-04-25T00:00:00.000Z',
        'updatedAt': '2026-04-25T00:00:00.000Z',
        'templateName': 'Closing Checklist',
        'translations': {
          'pt': {'templateName': 'Checklist de fechamento'},
        },
        'tasks': const [],
      }, 'checklist-2');

      expect(checklist.templateName, 'Checklist de fechamento');
    });
  });
}
