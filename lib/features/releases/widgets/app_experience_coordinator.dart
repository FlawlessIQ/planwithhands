import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/features/releases/models/app_release_manifest.dart';
import 'package:hands_app/features/releases/services/app_release_service.dart';
import 'package:hands_app/features/releases/services/app_release_storage.dart';
import 'package:hands_app/features/releases/widgets/app_release_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppExperienceCoordinator extends StatefulWidget {
  final GoRouter router;
  final Widget child;

  const AppExperienceCoordinator({
    super.key,
    required this.router,
    required this.child,
  });

  @override
  State<AppExperienceCoordinator> createState() =>
      _AppExperienceCoordinatorState();
}

class _AppExperienceCoordinatorState extends State<AppExperienceCoordinator> {
  PackageInfo? _packageInfo;
  AppReleaseManifest? _manifest;
  bool _isReady = false;
  bool _isDialogVisible = false;
  final Set<String> _sessionSuppressed = <String>{};

  @override
  void initState() {
    super.initState();
    widget.router.routeInformationProvider.addListener(_onRouteChanged);
    _loadReleaseState();
  }

  @override
  void didUpdateWidget(covariant AppExperienceCoordinator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routeInformationProvider.removeListener(_onRouteChanged);
      widget.router.routeInformationProvider.addListener(_onRouteChanged);
      _scheduleEvaluation();
    }
  }

  @override
  void dispose() {
    widget.router.routeInformationProvider.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() => _scheduleEvaluation();

  Future<void> _loadReleaseState() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final manifest = await AppReleaseService.fetchManifest();
    if (!mounted) return;

    setState(() {
      _packageInfo = packageInfo;
      _manifest = manifest;
      _isReady = true;
    });

    _scheduleEvaluation();
  }

  void _scheduleEvaluation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_evaluatePrompt());
    });
  }

  Future<void> _evaluatePrompt() async {
    if (!_isReady || _isDialogVisible) return;

    final manifest = _manifest;
    final packageInfo = _packageInfo;
    if (manifest == null || packageInfo == null) return;
    if (FirebaseAuth.instance.currentUser == null) return;

    final currentPath =
        widget.router.routeInformationProvider.value.uri.toString();

    final decision = await AppReleaseService.evaluate(
      manifest: manifest,
      packageInfo: packageInfo,
      currentPath: currentPath,
    );

    if (!mounted || decision == null) return;
    if (_sessionSuppressed.contains(decision.sessionKey)) return;

    if (decision.type == AppReleasePromptType.whatsNew) {
      // Treat the release prompt itself as a once-off announcement.
      // We persist this before showing the dialog so it does not keep
      // resurfacing if the dialog is interrupted by navigation or reload.
      await AppReleaseStorage.markReleaseSeen(
        decision.role,
        decision.releaseId,
      );
      if (!mounted) return;
    }

    _isDialogVisible = true;
    final result = await showDialog<AppReleaseDialogResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AppReleaseDialog(decision: decision),
    );
    _isDialogVisible = false;

    if (!mounted) return;

    switch (decision.type) {
      case AppReleasePromptType.whatsNew:
        if (result == AppReleaseDialogResult.primary) {
          await AppReleaseService.handlePrimaryAction(context, decision);
        }
        _sessionSuppressed.add(decision.sessionKey);
        return;
      case AppReleasePromptType.updateAvailable:
        if (result == AppReleaseDialogResult.primary) {
          await AppReleaseService.handlePrimaryAction(context, decision);
        }
        _sessionSuppressed.add(decision.sessionKey);
        return;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
