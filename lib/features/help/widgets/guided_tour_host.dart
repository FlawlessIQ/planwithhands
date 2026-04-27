import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/features/help/models/guided_tour_step.dart';
import 'package:hands_app/features/help/models/help_topic.dart';
import 'package:hands_app/features/help/services/guided_tour_service.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GuidedTourHost extends StatefulWidget {
  final String storageKey;
  final List<GuidedTourStep> steps;
  final Widget child;
  final bool enabled;
  final Duration initialDelay;

  const GuidedTourHost({
    super.key,
    required this.storageKey,
    required this.steps,
    required this.child,
    this.enabled = true,
    this.initialDelay = const Duration(milliseconds: 900),
  });

  @override
  State<GuidedTourHost> createState() => _GuidedTourHostState();
}

class _GuidedTourHostState extends State<GuidedTourHost> {
  static const _prefPrefix = 'guided_tour_seen_';
  static const _seenTourKeysField = 'seenTourKeys';

  bool _prefsLoading = true;
  bool _hasSeenTour = false;
  bool _isActive = false;
  bool _isPreparingStep = false;
  bool _startScheduled = false;
  int _currentStepIndex = 0;
  Rect? _targetRect;
  Timer? _startTimer;
  StreamSubscription<String>? _replaySubscription;

  @override
  void initState() {
    super.initState();
    _replaySubscription = GuidedTourService.replayRequests.listen((storageKey) {
      if (storageKey != widget.storageKey) return;
      unawaited(_handleExternalReplay());
    });
    _loadPrefs();
  }

  @override
  void didUpdateWidget(covariant GuidedTourHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.steps.length != widget.steps.length) {
      _maybeScheduleStart();
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _replaySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final localKey = '$_prefPrefix${widget.storageKey}';
    var hasSeen = prefs.getBool(localKey) ?? false;
    if (!hasSeen) {
      hasSeen = await _hasSeenTourRemotely();
      if (hasSeen) {
        await prefs.setBool(localKey, true);
      }
    }
    if (!mounted) return;
    setState(() {
      _hasSeenTour = hasSeen;
      _prefsLoading = false;
    });
    _maybeScheduleStart();
  }

  Future<void> _markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefPrefix${widget.storageKey}', true);
    await _markSeenRemotely();
    _hasSeenTour = true;
  }

  Future<bool> _hasSeenTourRemotely() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return false;

    try {
      final snapshot =
          await FirestoreEnforcer.instance
              .collection('users')
              .doc(uid)
              .collection('preferences')
              .doc('experience')
              .get();
      final data = snapshot.data();
      final seenKeys =
          (data?[_seenTourKeysField] as List<dynamic>? ?? const [])
              .map((value) => value.toString())
              .toSet();
      return seenKeys.contains(widget.storageKey);
    } catch (_) {
      return false;
    }
  }

  Future<void> _markSeenRemotely() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    try {
      await FirestoreEnforcer.instance
          .collection('users')
          .doc(uid)
          .collection('preferences')
          .doc('experience')
          .set({
            _seenTourKeysField: FieldValue.arrayUnion([widget.storageKey]),
          }, SetOptions(merge: true));
    } catch (_) {
      // Local persistence still prevents repeat prompts in the current client.
    }
  }

  Future<void> _handleExternalReplay() async {
    _startTimer?.cancel();
    if (!mounted || !widget.enabled || widget.steps.isEmpty) return;

    setState(() {
      _hasSeenTour = false;
      _prefsLoading = false;
      _isActive = true;
      _currentStepIndex = 0;
      _targetRect = null;
    });

    await _prepareCurrentStep();
  }

  void _maybeScheduleStart() {
    if (_prefsLoading ||
        _hasSeenTour ||
        _isActive ||
        _startScheduled ||
        !widget.enabled ||
        widget.steps.isEmpty) {
      return;
    }

    _startScheduled = true;
    _startTimer?.cancel();
    _startTimer = Timer(widget.initialDelay, () async {
      _startScheduled = false;
      if (!mounted ||
          _prefsLoading ||
          _hasSeenTour ||
          !widget.enabled ||
          widget.steps.isEmpty) {
        return;
      }

      setState(() {
        _isActive = true;
        _currentStepIndex = 0;
        _targetRect = null;
      });
      await _prepareCurrentStep();
    });
  }

  Future<void> _prepareCurrentStep() async {
    if (!mounted || !_isActive || widget.steps.isEmpty) return;
    if (_currentStepIndex < 0 || _currentStepIndex >= widget.steps.length) {
      await _finishTour();
      return;
    }

    if (_isPreparingStep) return;
    _isPreparingStep = true;

    final step = widget.steps[_currentStepIndex];
    if (step.targetKey == null) {
      setState(() => _targetRect = null);
      _isPreparingStep = false;
      return;
    }

    BuildContext? targetContext = step.targetKey!.currentContext;

    for (var attempt = 0; attempt < 4 && targetContext == null; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      targetContext = step.targetKey!.currentContext;
    }

    if (targetContext == null) {
      _isPreparingStep = false;
      await _advanceFromMissingTarget();
      return;
    }

    try {
      await _scrollTargetIntoView(step.targetKey!, step.scrollAlignment);
    } catch (_) {
      // Some targets may not sit under a Scrollable. That's fine.
    }

    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    final rect = _measureTarget(step.targetKey!, step.highlightPadding);
    if (rect == null) {
      _isPreparingStep = false;
      await _advanceFromMissingTarget();
      return;
    }

    setState(() => _targetRect = rect);
    _isPreparingStep = false;
  }

  Future<void> _scrollTargetIntoView(
    GlobalKey targetKey,
    double alignment,
  ) async {
    final targetContext = targetKey.currentContext;
    if (targetContext == null) return;

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeInOut,
      alignment: alignment,
    );
  }

  Rect? _measureTarget(GlobalKey key, double padding) {
    final targetContext = key.currentContext;
    final renderObject = targetContext?.findRenderObject();
    final hostRenderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        hostRenderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize ||
        !hostRenderObject.attached ||
        !hostRenderObject.hasSize) {
      return null;
    }

    final globalOffset = renderObject.localToGlobal(Offset.zero);
    final localOffset = hostRenderObject.globalToLocal(globalOffset);
    final rect = localOffset & renderObject.size;
    return Rect.fromLTRB(
      rect.left - padding,
      rect.top - padding,
      rect.right + padding,
      rect.bottom + padding,
    );
  }

  Future<void> _advanceFromMissingTarget() async {
    if (_currentStepIndex >= widget.steps.length - 1) {
      await _finishTour();
      return;
    }

    setState(() {
      _currentStepIndex += 1;
      _targetRect = null;
    });
    await _prepareCurrentStep();
  }

  Future<void> _goToStep(int index) async {
    if (!mounted) return;
    setState(() {
      _currentStepIndex = index.clamp(0, widget.steps.length - 1);
      _targetRect = null;
    });
    await _prepareCurrentStep();
  }

  Future<void> _nextStep() async {
    if (_currentStepIndex >= widget.steps.length - 1) {
      await _finishTour();
      return;
    }
    await _goToStep(_currentStepIndex + 1);
  }

  Future<void> _previousStep() async {
    if (_currentStepIndex <= 0) return;
    await _goToStep(_currentStepIndex - 1);
  }

  Future<void> _finishTour() async {
    await _markSeen();
    if (!mounted) return;
    setState(() {
      _isActive = false;
      _targetRect = null;
    });
  }

  Future<void> _openLearnMore(GuidedTourStep step) async {
    if (step.topicId == null || step.topicId!.trim().isEmpty) return;
    await _markSeen();
    if (!mounted) return;
    setState(() {
      _isActive = false;
      _targetRect = null;
    });
    context.push(HelpNav.topic(step.topicId!));
  }

  @override
  Widget build(BuildContext context) {
    final currentStep =
        (_isActive && widget.steps.isNotEmpty)
            ? widget.steps[_currentStepIndex]
            : null;

    return Stack(
      children: [
        widget.child,
        if (_isActive && currentStep != null)
          Positioned.fill(
            child: _GuidedTourOverlay(
              step: currentStep,
              currentStepIndex: _currentStepIndex,
              totalSteps: widget.steps.length,
              targetRect: _targetRect,
              onBack: _currentStepIndex == 0 ? null : _previousStep,
              onNext: _nextStep,
              onSkip: _finishTour,
              onLearnMore:
                  currentStep.topicId == null
                      ? null
                      : () => _openLearnMore(currentStep),
            ),
          ),
      ],
    );
  }
}

class _GuidedTourOverlay extends StatelessWidget {
  final GuidedTourStep step;
  final int currentStepIndex;
  final int totalSteps;
  final Rect? targetRect;
  final Future<void> Function()? onBack;
  final Future<void> Function() onNext;
  final Future<void> Function() onSkip;
  final Future<void> Function()? onLearnMore;

  const _GuidedTourOverlay({
    required this.step,
    required this.currentStepIndex,
    required this.totalSteps,
    required this.targetRect,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
    required this.onLearnMore,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mediaQuery = MediaQuery.of(context);
          final overlaySize = Size(constraints.maxWidth, constraints.maxHeight);
          final isCompactScreen = overlaySize.width < 700;
          final safeTop = 12.0;
          final safeBottom =
              mediaQuery.padding.bottom + (isCompactScreen ? 104.0 : 24.0);
          final useBottomSheetLayout = isCompactScreen;
          final cardWidth =
              useBottomSheetLayout
                  ? overlaySize.width - 24
                  : math.min(overlaySize.width - 32, 360.0);
          final rect = targetRect;
          final availableViewportHeight =
              overlaySize.height - safeTop - safeBottom;
          const minCardHeight = 220.0;
          final estimatedCardHeight =
              onLearnMore != null || onBack != null ? 316.0 : 288.0;
          final availableBelow =
              rect == null
                  ? availableViewportHeight
                  : math.max(
                    0.0,
                    overlaySize.height - safeBottom - rect.bottom - 14,
                  );
          final availableAbove =
              rect == null
                  ? availableViewportHeight
                  : math.max(0.0, rect.top - safeTop - 14);
          bool placeBelow =
              step.placement == GuidedTourCardPlacement.below ||
              (step.placement == GuidedTourCardPlacement.auto &&
                  (rect == null || rect.center.dy < overlaySize.height * 0.46));

          if (rect != null) {
            final preferredSpace = placeBelow ? availableBelow : availableAbove;
            final alternateSpace = placeBelow ? availableAbove : availableBelow;
            if (preferredSpace < minCardHeight &&
                alternateSpace > preferredSpace) {
              placeBelow = !placeBelow;
            }
          }

          final cardMaxHeight =
              useBottomSheetLayout
                  ? math.min(estimatedCardHeight, overlaySize.height * 0.42)
                  : rect == null
                  ? math.min(estimatedCardHeight, availableViewportHeight)
                  : math.max(
                    minCardHeight,
                    math.min(
                      placeBelow ? availableBelow : availableAbove,
                      availableViewportHeight,
                    ),
                  );
          final horizontalMargin = useBottomSheetLayout ? 12.0 : 16.0;
          final centeredLeft = math.max(
            horizontalMargin,
            (overlaySize.width - cardWidth) / 2,
          );
          final maxLeft = math.max(
            horizontalMargin,
            overlaySize.width - cardWidth - horizontalMargin,
          );
          final left =
              rect == null || useBottomSheetLayout
                  ? centeredLeft
                  : rect.left.clamp(horizontalMargin, maxLeft).toDouble();
          final maxTop = math.max(
            safeTop,
            overlaySize.height - cardMaxHeight - safeBottom,
          );
          final top =
              useBottomSheetLayout
                  ? maxTop
                  : rect == null
                  ? ((overlaySize.height - cardMaxHeight) / 2).clamp(
                    safeTop,
                    maxTop,
                  )
                  : placeBelow
                  ? (rect.bottom + 14).clamp(safeTop, maxTop)
                  : (rect.top - cardMaxHeight - 14).clamp(safeTop, maxTop);

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GuidedTourScrimPainter(targetRect: rect),
                ),
              ),
              Positioned.fill(child: GestureDetector(onTap: () {})),
              Positioned(
                left: useBottomSheetLayout ? 12 : left,
                top: top,
                width: cardWidth,
                child: _buildCard(context, cardMaxHeight),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard(BuildContext context, double maxHeight) {
    final l10n = context.l10n;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x36000000),
              blurRadius: 28,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: HandsColors.handsOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l10n.guidedTourStepCounter(
                        currentStepIndex + 1,
                        totalSteps,
                      ),
                      style: GoogleFonts.inter(
                        color: HandsColors.handsOrange,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onSkip,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        l10n.guidedTourSkip,
                        style: GoogleFonts.inter(
                          color: HandsColors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                step.title,
                style: GoogleFonts.inter(
                  color: HandsColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                step.description,
                style: GoogleFonts.inter(
                  color: HandsColors.white.withValues(alpha: 0.74),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
              if (currentStepIndex == 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HandsColors.handsOrange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: HandsColors.handsOrange.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.language_rounded,
                          color: HandsColors.handsOrange,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.guidedTourLanguageFeatureTitle,
                              style: GoogleFonts.inter(
                                color: HandsColors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.guidedTourLanguageFeatureBody,
                              style: GoogleFonts.inter(
                                color: HandsColors.white.withValues(
                                  alpha: 0.72,
                                ),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  if (onLearnMore != null)
                    TextButton(
                      onPressed: onLearnMore,
                      style: TextButton.styleFrom(
                        foregroundColor: HandsColors.handsOrange,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                      child: Text(
                        l10n.guidedTourLearnMore,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
                  if (onBack != null)
                    OutlinedButton(
                      onPressed: onBack,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HandsColors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        l10n.guidedTourBack,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (onBack != null) const SizedBox(width: 10),
                  FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: HandsColors.handsOrange,
                      foregroundColor: HandsColors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      currentStepIndex == totalSteps - 1
                          ? l10n.guidedTourDone
                          : l10n.guidedTourNext,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuidedTourScrimPainter extends CustomPainter {
  final Rect? targetRect;

  const _GuidedTourScrimPainter({required this.targetRect});

  @override
  void paint(Canvas canvas, Size size) {
    final scrimPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.72)
          ..style = PaintingStyle.fill;

    final fullPath =
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutRect = targetRect;
    if (cutoutRect == null) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), scrimPaint);
      return;
    }

    final roundedRect = RRect.fromRectAndRadius(
      cutoutRect,
      const Radius.circular(18),
    );
    final cutoutPath = Path()..addRRect(roundedRect);
    final overlayPath = Path.combine(
      PathOperation.difference,
      fullPath,
      cutoutPath,
    );

    canvas.drawPath(overlayPath, scrimPaint);

    final borderPaint =
        Paint()
          ..color = HandsColors.handsOrange.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    canvas.drawRRect(roundedRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _GuidedTourScrimPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}
