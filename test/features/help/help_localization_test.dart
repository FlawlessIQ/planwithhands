import 'package:flutter_test/flutter_test.dart';
import 'package:hands_app/features/help/data/help_topics.dart';
import 'package:hands_app/features/help/models/help_topic.dart';
import 'package:hands_app/features/help/services/guided_tour_service.dart';

void main() {
  group('Help localization', () {
    test('staff first-shift topic resolves Portuguese content', () {
      final topic = HelpTopics.byId('staff-first-shift')!;

      expect(topic.titleForLocale('pt-BR'), 'Conclua seu primeiro turno');
      expect(topic.primaryCtaLabelForLocale('pt'), 'Abrir tarefas de hoje');
      expect(
        topic.stepsForLocale('pt').first,
        'Abra Tarefas de hoje e confirme o local atual no topo da tela.',
      );
    });

    test('staff troubleshooting topic resolves Portuguese fallback', () {
      final topic = HelpTopics.byId('staff-trouble-missing-shift')!;

      expect(topic.titleForLocale('pt-BR'), 'Nao consigo ver meu turno');
      expect(topic.primaryCtaLabelForLocale('pt'), 'Falar com o suporte');
    });

    test('staff start guide resolves Portuguese labels', () {
      final guide = HelpTopics.guideForRole(HelpRole.staff);

      expect(guide.titleForLocale('pt-BR'), 'Conclua seu primeiro turno');
      expect(guide.primaryCtaLabelForLocale('pt'), 'Abrir tarefas de hoje');
      expect(guide.steps.first.titleForLocale('pt'), 'Confirme seu local');
    });

    test('guided tour definition resolves Portuguese labels', () {
      final definition = GuidedTourService.definitionForRole(HelpRole.staff);

      expect(
        definition.titleForLocale('pt-BR'),
        'Repetir tour das tarefas da equipe',
      );
      expect(
        definition.descriptionForLocale('pt'),
        'Veja novamente a localização, o resumo do turno, o Proximo item e o trabalho de hoje.',
      );
    });
  });
}
