import 'package:flutter/material.dart';

enum GuidedTourCardPlacement { auto, above, below }

class GuidedTourStep {
  final GlobalKey? targetKey;
  final String title;
  final String description;
  final String? topicId;
  final double scrollAlignment;
  final double highlightPadding;
  final GuidedTourCardPlacement placement;

  const GuidedTourStep({
    this.targetKey,
    required this.title,
    required this.description,
    this.topicId,
    this.scrollAlignment = 0.12,
    this.highlightPadding = 10,
    this.placement = GuidedTourCardPlacement.auto,
  });
}
