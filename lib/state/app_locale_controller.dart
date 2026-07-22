import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:hands_app/constants/firestore_names.dart';
import 'package:hands_app/services/local_storage_service.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

const String _preferredLanguageStorageKey = 'preferred_language_code';

class AppLocaleState {
  const AppLocaleState({
    required this.locale,
    required this.isInitialized,
    required this.hasExplicitPreference,
  });

  const AppLocaleState.initial()
    : locale = const Locale('en'),
      isInitialized = false,
      hasExplicitPreference = false;

  final Locale locale;
  final bool isInitialized;
  final bool hasExplicitPreference;

  AppLocaleState copyWith({
    Locale? locale,
    bool? isInitialized,
    bool? hasExplicitPreference,
  }) {
    return AppLocaleState(
      locale: locale ?? this.locale,
      isInitialized: isInitialized ?? this.isInitialized,
      hasExplicitPreference:
          hasExplicitPreference ?? this.hasExplicitPreference,
    );
  }
}

class AppLocaleController extends StateNotifier<AppLocaleState> {
  AppLocaleController() : super(const AppLocaleState.initial()) {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      unawaited(_handleAuthChanged(user));
    });
  }

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('es'),
    Locale('pt'),
  ];
  static const Locale fallbackLocale = Locale('en');

  final FirebaseFirestore _firestore = FirestoreEnforcer.instance;
  StreamSubscription<User?>? _authSubscription;
  String? _pendingRemoteSyncSource;

  Future<void> initialize() async {
    if (state.isInitialized) return;

    await initializeDateFormatting('en');
    await initializeDateFormatting('es');
    await initializeDateFormatting('pt');

    final savedLanguageCode = LocalStorageService.getString(
      _preferredLanguageStorageKey,
    );
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final resolvedLocale =
        _resolveLocale(savedLanguageCode) ??
        _resolveLocale(deviceLocale.toLanguageTag()) ??
        _resolveLocale(deviceLocale.languageCode) ??
        fallbackLocale;

    _applyLocale(resolvedLocale);
    state = state.copyWith(
      locale: resolvedLocale,
      isInitialized: true,
      hasExplicitPreference: savedLanguageCode != null,
    );

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await _handleAuthChanged(currentUser);
    }
  }

  Future<void> setLocale(
    Locale locale, {
    bool persist = true,
    String source = 'user_selected',
  }) async {
    final normalizedLocale = _normalizeLocale(locale);
    _applyLocale(normalizedLocale);
    state = state.copyWith(
      locale: normalizedLocale,
      isInitialized: true,
      hasExplicitPreference: true,
    );

    if (persist) {
      await LocalStorageService.saveString(
        _preferredLanguageStorageKey,
        normalizedLocale.toLanguageTag(),
      );
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await _persistRemotePreference(currentUser.uid, normalizedLocale, source);
      _pendingRemoteSyncSource = null;
    } else if (persist) {
      _pendingRemoteSyncSource = source;
    }
  }

  Locale? _resolveLocale(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) return null;
    final normalizedValue = rawValue.trim().replaceAll('_', '-').toLowerCase();
    if (normalizedValue.startsWith('pt')) {
      return const Locale('pt');
    }
    if (normalizedValue.startsWith('es')) return const Locale('es');
    if (normalizedValue.startsWith('en')) return const Locale('en');
    return null;
  }

  Locale _normalizeLocale(Locale locale) {
    return _resolveLocale(locale.toLanguageTag()) ?? fallbackLocale;
  }

  void _applyLocale(Locale locale) {
    Intl.defaultLocale = locale.toLanguageTag();
  }

  Future<void> _handleAuthChanged(User? user) async {
    if (!state.isInitialized || user == null) return;

    try {
      final userDoc =
          await _firestore
              .collection(FirestoreCollectionNames.users)
              .doc(user.uid)
              .get();
      final userData = userDoc.data() ?? <String, dynamic>{};
      final remoteLocale = _resolveLocale(
        userData[UserFieldNames.preferredLanguageCode]?.toString(),
      );
      final pendingSyncSource = _pendingRemoteSyncSource;

      if (pendingSyncSource != null && state.hasExplicitPreference) {
        await _persistRemotePreference(
          user.uid,
          state.locale,
          pendingSyncSource,
        );
        _pendingRemoteSyncSource = null;
        return;
      }

      if (remoteLocale != null) {
        _applyLocale(remoteLocale);
        state = state.copyWith(
          locale: remoteLocale,
          hasExplicitPreference: true,
        );
        await LocalStorageService.saveString(
          _preferredLanguageStorageKey,
          remoteLocale.toLanguageTag(),
        );
        _pendingRemoteSyncSource = null;
        return;
      }

      await _persistRemotePreference(
        user.uid,
        state.locale,
        state.hasExplicitPreference ? 'user_selected' : 'device',
      );
      _pendingRemoteSyncSource = null;
    } catch (error) {
      debugPrint('[AppLocaleController] Failed to sync locale: $error');
    }
  }

  Future<void> _persistRemotePreference(
    String userId,
    Locale locale,
    String source,
  ) async {
    await _firestore
        .collection(FirestoreCollectionNames.users)
        .doc(userId)
        .set({
          UserFieldNames.preferredLanguageCode: locale.toLanguageTag(),
          UserFieldNames.preferredLanguageSource: source,
          UserFieldNames.preferredLocaleResolved: locale.toLanguageTag(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final appLocaleControllerProvider =
    StateNotifierProvider<AppLocaleController, AppLocaleState>(
      (ref) => AppLocaleController(),
    );
