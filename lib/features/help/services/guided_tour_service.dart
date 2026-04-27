import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/features/help/models/help_topic.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GuidedTourDefinition {
  final HelpRole role;
  final String title;
  final String description;
  final String storageKey;
  final String route;
  final IconData icon;
  final Map<String, String> localizedTitles;
  final Map<String, String> localizedDescriptions;

  const GuidedTourDefinition({
    required this.role,
    required this.title,
    required this.description,
    required this.storageKey,
    required this.route,
    required this.icon,
    this.localizedTitles = const {},
    this.localizedDescriptions = const {},
  });

  String titleForLocale(String localeCode) =>
      _localizedString(localizedTitles, title, localeCode);

  String descriptionForLocale(String localeCode) =>
      _localizedString(localizedDescriptions, description, localeCode);
}

String _normalizeLocaleKey(String localeCode) =>
    localeCode.toLowerCase().replaceAll('_', '-');

List<String> _localeCandidates(String localeCode) {
  final normalized = _normalizeLocaleKey(localeCode);
  final languageCode = normalized.split('-').first;
  return normalized == languageCode ? [normalized] : [normalized, languageCode];
}

String _localizedString(
  Map<String, String> values,
  String fallback,
  String localeCode,
) {
  for (final candidate in _localeCandidates(localeCode)) {
    final resolved = values[candidate];
    if (resolved != null && resolved.trim().isNotEmpty) {
      return resolved;
    }
  }
  return fallback;
}

class GuidedTourService {
  static const _prefix = 'guided_tour_seen_';
  static const _seenTourKeysField = 'seenTourKeys';
  static final StreamController<String> _replayRequests =
      StreamController<String>.broadcast();

  static Stream<String> get replayRequests => _replayRequests.stream;

  static GuidedTourDefinition definitionForRole(HelpRole role) {
    return switch (role) {
      HelpRole.staff => const GuidedTourDefinition(
        role: HelpRole.staff,
        title: 'Replay staff tasks tour',
        description:
            'Walk through location, shift summary, Next Up, and Today’s Work again.',
        storageKey: 'staff-dashboard-tour-v1',
        route: HelpDestinations.userDashboard,
        icon: Icons.task_alt_rounded,
        localizedTitles: {
          'es': 'Repetir recorrido de tareas del personal',
          'pt': 'Repetir tour das tarefas da equipe',
        },
        localizedDescriptions: {
          'es':
              'Recorre de nuevo la ubicación, el resumen del turno, Next Up y el trabajo de hoy.',
          'pt':
              'Veja novamente a localização, o resumo do turno, o Proximo item e o trabalho de hoje.',
        },
      ),
      HelpRole.manager => const GuidedTourDefinition(
        role: HelpRole.manager,
        title: 'Replay manager dashboard tour',
        description:
            'Review the summary card, Today at Risk, and Shift Readiness again.',
        storageKey: 'manager-dashboard-tour-v1',
        route: HelpDestinations.managerDashboard,
        icon: Icons.analytics_outlined,
        localizedTitles: {
          'es': 'Repetir recorrido del panel de gerente',
          'pt': 'Repetir tour do painel do gerente',
        },
        localizedDescriptions: {
          'es':
              'Revisa de nuevo la tarjeta de resumen, Hoy en riesgo y la preparación del turno.',
          'pt':
              'Revise novamente o cartao de resumo, Hoje em risco e a preparacao do turno.',
        },
      ),
      HelpRole.admin => const GuidedTourDefinition(
        role: HelpRole.admin,
        title: 'Replay admin setup tour',
        description:
            'Walk through location scope, setup areas, and the main setup workspace again.',
        storageKey: 'admin-setup-tour-v2',
        route: HelpDestinations.adminDashboard,
        icon: Icons.settings_suggest_outlined,
        localizedTitles: {
          'es': 'Repetir recorrido de configuración admin',
          'pt': 'Repetir tour de configuracao do admin',
        },
        localizedDescriptions: {
          'es':
              'Recorre de nuevo el alcance de ubicaciones, las áreas de configuración y el espacio principal de trabajo.',
          'pt':
              'Veja novamente o escopo de locais, as areas de configuracao e o espaco principal de trabalho.',
        },
      ),
    };
  }

  static Future<void> resetTour(String storageKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$storageKey');
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      await FirestoreEnforcer.instance
          .collection('users')
          .doc(uid)
          .collection('preferences')
          .doc('experience')
          .set({
            _seenTourKeysField: FieldValue.arrayRemove([storageKey]),
          }, SetOptions(merge: true));
    } catch (_) {
      // Replay should still work locally even if the remote reset fails.
    }
  }

  static void requestReplay(String storageKey) {
    _replayRequests.add(storageKey);
  }

  static Future<void> replayForRole(BuildContext context, HelpRole role) async {
    final definition = definitionForRole(role);
    await resetTour(definition.storageKey);
    if (!context.mounted) return;

    final currentPath = GoRouterState.of(context).uri.path;
    final targetPath = Uri.parse(definition.route).path;

    if (currentPath == targetPath) {
      requestReplay(definition.storageKey);
      return;
    }

    context.go(definition.route);
  }
}
