import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/features/help/models/help_topic.dart';
import 'package:hands_app/features/releases/services/app_release_service.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/shared/components/shared_components.dart';

enum AppReleaseDialogResult { primary, dismiss }

class AppReleaseDialog extends StatelessWidget {
  final AppReleasePromptDecision decision;

  const AppReleaseDialog({super.key, required this.decision});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final localeCode = Localizations.localeOf(context).toLanguageTag();
    final isUpdate = decision.type == AppReleasePromptType.updateAvailable;
    final accent = decision.role.accentColor;
    final hasUpdateAction = kIsWeb || (decision.updateUrl?.isNotEmpty ?? false);
    final localizedTitle = decision.content.titleForLocale(localeCode);
    final localizedBody = decision.content.bodyForLocale(localeCode);
    final localizedBullets = decision.content.bulletsForLocale(localeCode);
    final primaryLabel =
        isUpdate
            ? (hasUpdateAction
                ? (kIsWeb
                    ? l10n.releaseDialogRefreshNow
                    : l10n.releaseDialogUpdateNow)
                : l10n.releaseDialogOkay)
            : l10n.releaseDialogTakeGuidedTour;
    final primaryIcon =
        isUpdate
            ? (hasUpdateAction
                ? Icons.system_update_alt_rounded
                : Icons.check_rounded)
            : Icons.play_arrow_rounded;

    return HandsDialog(
      title: isUpdate ? l10n.releaseDialogUpdateTitle : localizedTitle,
      subtitle:
          isUpdate
              ? l10n.releaseDialogUpdateSubtitle
              : l10n.releaseDialogWhatsNewSubtitle,
      maxWidth: 640,
      actions: [
        HandsSecondaryButton(
          text: l10n.releaseDialogNotNow,
          onPressed:
              () => Navigator.of(context).pop(AppReleaseDialogResult.dismiss),
        ),
        HandsPrimaryButton(
          text: primaryLabel,
          icon: primaryIcon,
          onPressed:
              () => Navigator.of(context).pop(AppReleaseDialogResult.primary),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: HandsModalTokens.surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: HandsModalTokens.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isUpdate
                        ? Icons.system_update_alt_rounded
                        : Icons.auto_awesome_rounded,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isUpdate
                              ? l10n.releaseDialogMajorReleaseBadge
                              : l10n.releaseDialogNewExperienceBadge,
                          style: GoogleFonts.inter(
                            color: accent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        localizedBody,
                        style: HandsModalTokens.bodyStyle.copyWith(
                          color: HandsModalTokens.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.language_rounded, color: accent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.releaseDialogLanguageFeatureTitle,
                        style: GoogleFonts.inter(
                          color: HandsModalTokens.text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.releaseDialogLanguageFeatureBody,
                        style: HandsModalTokens.bodyStyle.copyWith(
                          color: HandsModalTokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.releaseDialogWhatChanged,
            style: HandsModalTokens.sectionTitleStyle,
          ),
          const SizedBox(height: 10),
          ...localizedBullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      bullet,
                      style: HandsModalTokens.bodyStyle.copyWith(
                        color: HandsModalTokens.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
