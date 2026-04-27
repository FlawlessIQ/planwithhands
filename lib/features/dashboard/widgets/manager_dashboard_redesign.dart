import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:hands_app/features/help/widgets/context_help_trigger.dart';
import 'package:hands_app/theme/theme.dart';

enum DashboardTone { danger, warning, success, neutral }

class DashboardMetricSummary {
  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final DashboardTone tone;
  final double progress;

  const DashboardMetricSummary({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.tone,
    required this.progress,
  });
}

class ManagerActionIssue {
  final String title;
  final String detail;
  final String ctaLabel;
  final DashboardTone tone;
  final VoidCallback onTap;

  const ManagerActionIssue({
    required this.title,
    required this.detail,
    required this.ctaLabel,
    required this.tone,
    required this.onTap,
  });
}

class ShiftReadinessSummary {
  final String name;
  final String statusLabel;
  final String detail;
  final String timeLabel;
  final DashboardTone tone;
  final double readiness;
  final int completed;
  final int total;
  final int attentionCount;
  final VoidCallback onTap;

  const ShiftReadinessSummary({
    required this.name,
    required this.statusLabel,
    required this.detail,
    required this.timeLabel,
    required this.tone,
    required this.readiness,
    required this.completed,
    required this.total,
    required this.attentionCount,
    required this.onTap,
  });
}

class RecurringIssueSummary {
  final String title;
  final String subtitle;
  final String metric;
  final DashboardTone tone;
  final double progress;

  const RecurringIssueSummary({
    required this.title,
    required this.subtitle,
    required this.metric,
    required this.tone,
    required this.progress,
  });
}

class DashboardSectionLabel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<String> helpTopicIds;
  final String? helpTitle;
  final String? helpSubtitle;

  const DashboardSectionLabel({
    super.key,
    required this.title,
    this.subtitle,
    this.helpTopicIds = const [],
    this.helpTitle,
    this.helpSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _dashboardText(15, weight: FontWeight.w700)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: _dashboardText(
                    11.5,
                    color: HandsColors.white70,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (helpTopicIds.isNotEmpty) ...[
          const SizedBox(width: 10),
          ContextHelpTrigger(
            title: helpTitle ?? title,
            subtitle: helpSubtitle ?? subtitle,
            topicIds: helpTopicIds,
          ),
        ],
      ],
    );
  }
}

class DashboardSetupBanner extends StatelessWidget {
  final double completion;
  final VoidCallback onTap;

  const DashboardSetupBanner({
    super.key,
    required this.completion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: _dashboardSurface(radius: 18),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: HandsColors.handsOrange.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_motion,
              color: HandsColors.handsOrange,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Setup is still in progress',
                        style: _dashboardText(13.5, weight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${(completion.clamp(0.0, 1.0) * 100).round()}%',
                      style: _dashboardText(
                        12,
                        weight: FontWeight.w700,
                        color: HandsColors.handsOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Live signals are visible now, and they will sharpen as more setup steps are completed.',
                  style: _dashboardText(
                    11,
                    color: HandsColors.white70,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: completion.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: HandsColors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      HandsColors.handsOrange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: HandsColors.handsOrange,
              foregroundColor: HandsColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Open Setup',
              style: _dashboardText(12.5, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardHeroCard extends StatelessWidget {
  final String eyebrow;
  final String headline;
  final String summary;
  final List<DashboardMetricSummary> metrics;
  final String primaryLabel;
  final VoidCallback onPrimaryTap;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryTap;

  const DashboardHeroCard({
    super.key,
    required this.eyebrow,
    required this.headline,
    required this.summary,
    required this.metrics,
    required this.primaryLabel,
    required this.onPrimaryTap,
    this.secondaryLabel,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: _dashboardSurface(
        radius: 22,
        gradient: LinearGradient(
          colors: [
            const Color(0xFF20242C),
            const Color(0xFF1C2026),
            const Color(0xFF181B20),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              wide
                  ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _HeroCopy(
                          eyebrow: eyebrow,
                          headline: headline,
                          summary: summary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      _HeroActionCluster(
                        primaryLabel: primaryLabel,
                        onPrimaryTap: onPrimaryTap,
                        secondaryLabel: secondaryLabel,
                        onSecondaryTap: onSecondaryTap,
                        alignEnd: true,
                      ),
                    ],
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeroCopy(
                        eyebrow: eyebrow,
                        headline: headline,
                        summary: summary,
                      ),
                      const SizedBox(height: 14),
                      _HeroActionCluster(
                        primaryLabel: primaryLabel,
                        onPrimaryTap: onPrimaryTap,
                        secondaryLabel: secondaryLabel,
                        onSecondaryTap: onSecondaryTap,
                        alignEnd: false,
                      ),
                    ],
                  ),
              const SizedBox(height: 14),
              _HeroPulseBar(metrics: metrics),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, metricConstraints) {
                  final columns =
                      metricConstraints.maxWidth >= 860
                          ? 4
                          : metricConstraints.maxWidth >= 500
                          ? 2
                          : 1;
                  final spacing = 10.0;
                  final tileWidth =
                      (metricConstraints.maxWidth - ((columns - 1) * spacing)) /
                      columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children:
                        metrics
                            .take(4)
                            .map(
                              (metric) => SizedBox(
                                width: tileWidth,
                                child: _DashboardMetricTile(metric: metric),
                              ),
                            )
                            .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class DashboardIssueTile extends StatelessWidget {
  final ManagerActionIssue issue;

  const DashboardIssueTile({super.key, required this.issue});

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(issue.tone);
    final chartColor = _chartColor(issue.tone);
    return InkWell(
      onTap: issue.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _dashboardSurface(
          radius: 16,
          color: _surfaceRaised,
          borderColor: color.withValues(alpha: 0.16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [chartColor, color.withValues(alpha: 0.5)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _ToneChip(
                        label: _toneLabel(issue.tone),
                        tone: issue.tone,
                      ),
                      const Spacer(),
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: chartColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Icon(
                          Icons.chevron_right,
                          color: chartColor,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    issue.title,
                    style: _dashboardText(13.5, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    issue.detail,
                    style: _dashboardText(
                      11.5,
                      color: HandsColors.white70,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    issue.ctaLabel,
                    style: _dashboardText(
                      11.5,
                      weight: FontWeight.w700,
                      color: chartColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShiftReadinessPanel extends StatelessWidget {
  final List<ShiftReadinessSummary> shifts;
  final String emptyTitle;
  final String emptySubtitle;

  const ShiftReadinessPanel({
    super.key,
    required this.shifts,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (shifts.isEmpty) {
      return _EmptyDashboardCard(
        title: emptyTitle,
        subtitle: emptySubtitle,
        icon: Icons.schedule_outlined,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: _dashboardSurface(radius: 18),
      child: Column(
        children: [
          const _ShiftBoardHeader(),
          const SizedBox(height: 8),
          ...shifts.asMap().entries.map(
            (entry) => Padding(
              padding: EdgeInsets.only(
                bottom: entry.key < shifts.length - 1 ? 8 : 0,
              ),
              child: _ShiftReadinessRow(summary: entry.value),
            ),
          ),
        ],
      ),
    );
  }
}

class RecurringInsightsPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<RecurringIssueSummary> items;
  final String emptyLabel;

  const RecurringInsightsPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: _dashboardSurface(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: _dashboardText(13.5, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: _dashboardText(
                        11,
                        color: HandsColors.white70,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: HandsColors.white12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${items.length} tracked',
                    style: _dashboardText(10.5, color: HandsColors.white70),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              emptyLabel,
              style: _dashboardText(11.5, color: HandsColors.white70),
            )
          else
            ...items.asMap().entries.map(
              (entry) => Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key < items.length - 1 ? 10 : 0,
                ),
                child: _RecurringInsightRow(item: entry.value),
              ),
            ),
        ],
      ),
    );
  }
}

class HistoryReportsButton extends StatelessWidget {
  final VoidCallback onTap;

  const HistoryReportsButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.analytics_outlined, size: 17),
        style: OutlinedButton.styleFrom(
          foregroundColor: HandsColors.white,
          side: const BorderSide(color: HandsColors.white30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        ),
        label: Text(
          'History & Reports',
          style: _dashboardText(12.5, weight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  final String eyebrow;
  final String headline;
  final String summary;

  const _HeroCopy({
    required this.eyebrow,
    required this.headline,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: _dashboardText(
            11,
            weight: FontWeight.w600,
            color: HandsColors.white70,
            letterSpacing: 0.15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          headline,
          style: _dashboardText(
            24,
            weight: FontWeight.w700,
            height: 1.0,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          summary,
          style: _dashboardText(12.5, color: HandsColors.white70, height: 1.35),
        ),
      ],
    );
  }
}

class _HeroActionCluster extends StatelessWidget {
  final String primaryLabel;
  final VoidCallback onPrimaryTap;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryTap;
  final bool alignEnd;

  const _HeroActionCluster({
    required this.primaryLabel,
    required this.onPrimaryTap,
    required this.secondaryLabel,
    required this.onSecondaryTap,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        FilledButton(
          onPressed: onPrimaryTap,
          style: FilledButton.styleFrom(
            backgroundColor: HandsColors.handsOrange,
            foregroundColor: HandsColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            primaryLabel,
            style: _dashboardText(12.5, weight: FontWeight.w700),
          ),
        ),
        if (secondaryLabel != null && onSecondaryTap != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onSecondaryTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: HandsColors.white,
              side: const BorderSide(color: HandsColors.white30),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              secondaryLabel!,
              style: _dashboardText(12.5, weight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }
}

class _HeroPulseBar extends StatelessWidget {
  final List<DashboardMetricSummary> metrics;

  const _HeroPulseBar({required this.metrics});

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _surfaceInset,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _surfaceStroke),
      ),
      child: Row(
        children:
            metrics.take(4).map((metric) {
              final color = _chartColor(metric.tone);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(metric.icon, size: 11, color: color),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              metric.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _dashboardText(
                                10.5,
                                color: HandsColors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: metric.progress.clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: HandsColors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _DashboardMetricTile extends StatelessWidget {
  final DashboardMetricSummary metric;

  const _DashboardMetricTile({required this.metric});

  @override
  Widget build(BuildContext context) {
    final chartColor = _chartColor(metric.tone);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderTint(metric.tone)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: chartColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(metric.icon, size: 14, color: chartColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  metric.label,
                  style: _dashboardText(10.5, color: HandsColors.white70),
                ),
              ),
              Text(
                '${(metric.progress.clamp(0.0, 1.0) * 100).round()}%',
                style: _dashboardText(
                  10.5,
                  weight: FontWeight.w700,
                  color: chartColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            metric.value,
            style: _dashboardText(
              22,
              weight: FontWeight.w700,
              color: HandsColors.white,
              letterSpacing: -0.8,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metric.detail,
            style: _dashboardText(11, color: HandsColors.white70, height: 1.25),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: metric.progress.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: _surfaceTrack,
              valueColor: AlwaysStoppedAnimation<Color>(chartColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToneChip extends StatelessWidget {
  final String label;
  final DashboardTone tone;

  const _ToneChip({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _chipFill(tone),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: _dashboardText(10.5, weight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _ShiftBoardHeader extends StatelessWidget {
  const _ShiftBoardHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              'Shift',
              style: _dashboardText(10.5, color: HandsColors.white70),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              'Progress',
              style: _dashboardText(10.5, color: HandsColors.white70),
            ),
          ),
          SizedBox(
            width: 104,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Status',
                style: _dashboardText(10.5, color: HandsColors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftReadinessRow extends StatelessWidget {
  final ShiftReadinessSummary summary;

  const _ShiftReadinessRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final toneColor = _toneColor(summary.tone);
    final chartColor = _chartColor(summary.tone);
    final progress = summary.readiness.clamp(0.0, 1.0);
    final openTasks = (summary.total - summary.completed).clamp(
      0,
      summary.total,
    );

    return InkWell(
      onTap: summary.onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: _surfaceRaised,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _surfaceStroke),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.name,
                    style: _dashboardText(13, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary.timeLabel,
                    style: _dashboardText(10.5, color: HandsColors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary.detail,
                    style: _dashboardText(
                      10.5,
                      color: HandsColors.white70,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: _surfaceTrack,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              chartColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(progress * 100).round()}%',
                        style: _dashboardText(12, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _ShiftProgressTicks(
                    progress: progress,
                    toneColor: chartColor,
                    attentionCount: summary.attentionCount,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _MiniMetricPill(
                        label: '${summary.completed}/${summary.total}',
                        icon: Icons.checklist_rounded,
                      ),
                      const SizedBox(width: 6),
                      _MiniMetricPill(
                        label: '$openTasks open',
                        icon: Icons.pending_actions_outlined,
                        color:
                            openTasks == 0 ? HandsColors.sageGreen : chartColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 94,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _ToneChip(label: summary.statusLabel, tone: summary.tone),
                  if (summary.attentionCount > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${summary.attentionCount} flagged',
                      style: _dashboardText(
                        10.5,
                        weight: FontWeight.w700,
                        color: toneColor,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetricPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;

  const _MiniMetricPill({required this.label, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? HandsColors.white70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: _surfaceInset,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: _dashboardText(
              10,
              weight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecurringInsightRow extends StatelessWidget {
  final RecurringIssueSummary item;

  const _RecurringInsightRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final toneColor = _toneColor(item.tone);
    final chartColor = _chartColor(item.tone);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
        color: _surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _surfaceStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: toneColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: _dashboardText(12, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      style: _dashboardText(
                        10.5,
                        color: HandsColors.white70,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.metric,
                style: _dashboardText(
                  11.5,
                  weight: FontWeight.w700,
                  color: chartColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: item.progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: _surfaceTrack,
              valueColor: AlwaysStoppedAnimation<Color>(chartColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftProgressTicks extends StatelessWidget {
  final double progress;
  final Color toneColor;
  final int attentionCount;

  const _ShiftProgressTicks({
    required this.progress,
    required this.toneColor,
    required this.attentionCount,
  });

  @override
  Widget build(BuildContext context) {
    final completedSegments = (progress.clamp(0.0, 1.0) * 10).round();
    final attentionSegments = attentionCount > 0 ? 1 : 0;

    return Row(
      children: List.generate(10, (index) {
        final isCompleted = index < completedSegments;
        final isAttention = !isCompleted && index >= (10 - attentionSegments);
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == 9 ? 0 : 3),
            height: 4,
            decoration: BoxDecoration(
              color:
                  isCompleted
                      ? toneColor
                      : isAttention
                      ? _toneColor(DashboardTone.danger).withValues(alpha: 0.55)
                      : _surfaceTrack,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class _EmptyDashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _EmptyDashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _dashboardSurface(radius: 18),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: HandsColors.white12,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: HandsColors.white70, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _dashboardText(13.5, weight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: _dashboardText(
                    11,
                    color: HandsColors.white70,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _toneColor(DashboardTone tone) {
  switch (tone) {
    case DashboardTone.danger:
      return const Color(0xFFE08C78);
    case DashboardTone.warning:
      return const Color(0xFFE7A14C);
    case DashboardTone.success:
      return const Color(0xFF7FBC8C);
    case DashboardTone.neutral:
      return const Color(0xFF94A3BA);
  }
}

Color _chartColor(DashboardTone tone) {
  switch (tone) {
    case DashboardTone.danger:
      return const Color(0xFFF0A44F);
    case DashboardTone.warning:
      return const Color(0xFFF1B95C);
    case DashboardTone.success:
      return const Color(0xFF8DBA95);
    case DashboardTone.neutral:
      return const Color(0xFFA1AEC3);
  }
}

String _toneLabel(DashboardTone tone) {
  switch (tone) {
    case DashboardTone.danger:
      return 'Act now';
    case DashboardTone.warning:
      return 'Watch';
    case DashboardTone.success:
      return 'Stable';
    case DashboardTone.neutral:
      return 'Info';
  }
}

TextStyle _dashboardText(
  double size, {
  FontWeight weight = FontWeight.w500,
  Color color = HandsColors.white,
  double? height,
  double letterSpacing = -0.1,
}) {
  return GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

BoxDecoration _dashboardSurface({
  double radius = 18,
  Color color = _surfaceBase,
  Color borderColor = HandsColors.white12,
  Gradient? gradient,
}) {
  return BoxDecoration(
    color: gradient == null ? color : null,
    gradient: gradient,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor),
    boxShadow: const [
      BoxShadow(
        color: Color(0x24000000),
        blurRadius: 20,
        offset: Offset(0, 10),
      ),
    ],
  );
}

Color _chipFill(DashboardTone tone) {
  switch (tone) {
    case DashboardTone.danger:
      return const Color(0x33E08C78);
    case DashboardTone.warning:
      return const Color(0x33E7A14C);
    case DashboardTone.success:
      return const Color(0x338DBA95);
    case DashboardTone.neutral:
      return const Color(0x2894A3BA);
  }
}

Color _borderTint(DashboardTone tone) {
  switch (tone) {
    case DashboardTone.danger:
      return const Color(0x40E08C78);
    case DashboardTone.warning:
      return const Color(0x35E7A14C);
    case DashboardTone.success:
      return const Color(0x358DBA95);
    case DashboardTone.neutral:
      return _surfaceStroke;
  }
}

const Color _surfaceBase = Color(0xFF1D2026);
const Color _surfaceRaised = Color(0xFF23272F);
const Color _surfaceInset = Color(0xFF292E37);
const Color _surfaceTrack = Color(0xFF434A56);
const Color _surfaceStroke = Color(0xFF363C47);
