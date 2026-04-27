import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/state/app_locale_controller.dart';

class LanguageSelectorButton extends ConsumerWidget {
  const LanguageSelectorButton({
    super.key,
    this.showText = false,
    this.iconColor,
  });

  final bool showText;
  final Color? iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final localeState = ref.watch(appLocaleControllerProvider);
    final controller = ref.read(appLocaleControllerProvider.notifier);

    String currentCode =
        localeState.locale.countryCode == null
            ? localeState.locale.languageCode.toUpperCase()
            : localeState.locale.toLanguageTag().toUpperCase();

    return PopupMenuButton<String>(
      tooltip: l10n.languageTitle,
      initialValue: localeState.locale.toLanguageTag(),
      onSelected: (value) {
        if (value == 'pt') {
          controller.setLocale(const Locale('pt'));
          return;
        }
        controller.setLocale(Locale(value));
      },
      itemBuilder:
          (_) => [
            PopupMenuItem(value: 'en', child: Text(l10n.languageEnglish)),
            PopupMenuItem(value: 'es', child: Text(l10n.languageSpanish)),
            PopupMenuItem(value: 'pt', child: Text(l10n.languagePortuguese)),
          ],
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: showText ? 10 : 8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.language_rounded,
              size: 18,
              color: iconColor ?? Theme.of(context).colorScheme.onSurface,
            ),
            if (showText) ...[
              const SizedBox(width: 6),
              Text(currentCode, style: Theme.of(context).textTheme.labelLarge),
            ],
          ],
        ),
      ),
    );
  }
}
