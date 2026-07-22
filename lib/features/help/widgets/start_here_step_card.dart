import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/features/help/models/help_topic.dart';
import 'package:hands_app/theme/theme.dart';

class StartHereStepCard extends StatelessWidget {
  final HelpRole role;
  final int index;
  final HelpStartStep step;

  const StartHereStepCard({
    super.key,
    required this.role,
    required this.index,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.push(HelpNav.topic(step.topicId)),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFF171C24),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: role.accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.inter(
                    color: role.accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.titleForLocale(localeCode),
                      style: GoogleFonts.inter(
                        color: HandsColors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      step.descriptionForLocale(localeCode),
                      style: GoogleFonts.inter(
                        color: HandsColors.white.withValues(alpha: 0.68),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                color: HandsColors.white.withValues(alpha: 0.44),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
