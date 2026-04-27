import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hands_app/state/user_state.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
// Ensure userStateProvider is exported from user_state.dart
import 'package:hands_app/global_widgets/bottom_nav_bar.dart';
import 'package:hands_app/global_widgets/generic_app_bar_content.dart';
import 'package:hands_app/global_widgets/unified_menu_button.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/global_widgets/hands_icon.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/ui/UploadDocumentBottomSheet.dart';
import 'package:hands_app/services/location_selection_service.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/features/help/widgets/context_help_trigger.dart';
import 'package:hands_app/l10n/l10n.dart';

String localizedDocumentCategoryLabel(BuildContext context, String category) {
  switch (category) {
    case 'All':
      return context.l10n.documentsCategoryAll;
    case 'Safety Procedures':
      return context.l10n.documentsCategorySafetyProcedures;
    case 'Cleaning Protocols':
      return context.l10n.documentsCategoryCleaningProtocols;
    case 'Training Materials':
      return context.l10n.documentsCategoryTrainingMaterials;
    case 'Operating Procedures':
      return context.l10n.documentsCategoryOperatingProcedures;
    case 'Emergency Procedures':
      return context.l10n.documentsCategoryEmergencyProcedures;
    case 'Equipment Manuals':
      return context.l10n.documentsCategoryEquipmentManuals;
    case 'Policy Documents':
      return context.l10n.documentsCategoryPolicyDocuments;
    case 'Other':
      return context.l10n.documentsCategoryOther;
    default:
      return category;
  }
}

class ViewDocumentsPage extends HookConsumerWidget {
  const ViewDocumentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final userState = ref.watch(userStateProvider);

    // Get userRole from multiple sources with fallback
    int userRole = userState.userData?.userRole ?? 0;

    // Check for GoRouter extra parameter (from bottom nav)
    final routeExtra = GoRouterState.of(context).extra;
    if (routeExtra is Map<String, dynamic> &&
        routeExtra.containsKey('userRole')) {
      userRole = routeExtra['userRole'] as int? ?? userRole;
    }

    // Check for navigation argument (legacy support)
    final navArgs = ModalRoute.of(context)?.settings.arguments;
    if (navArgs is int) {
      userRole = navArgs;
    }

    final selectedCategory = useState<String>('All');
    final searchQuery = useState<String>('');
    final organizationId = useState<String?>(null);
    final isLoadingOrgId = useState<bool>(true);
    final availableLocations = useState<List<Map<String, dynamic>>>([]);

    // Use LocationSelectionService instead of local state
    final currentLocationId = useValueListenable(
      LocationSelectionService.instance.listenable,
    );

    // Helper to get current location name
    String getCurrentLocationName() {
      if (currentLocationId == null) return l10n.documentsAllLocations;
      try {
        final match = availableLocations.value.firstWhere(
          (l) => l['id'] == currentLocationId,
          orElse: () => <String, dynamic>{},
        );
        return match.isNotEmpty
            ? match['name'] as String
            : l10n.commonNotSpecified;
      } catch (_) {
        return l10n.commonNotSpecified;
      }
    }

    logger.d('DEBUG: userState: $userState');
    logger.d('DEBUG: userState.userData: ${userState.userData}');
    logger.d(
      'DEBUG: organizationId from userState: ${userState.userData?.organizationId}',
    );
    debugPrint('DEBUG: organizationId from useState: ${organizationId.value}');

    // Fallback mechanism to get organizationId directly from Firebase Auth/Firestore
    useEffect(() {
      Future<void> loadOrganizationId() async {
        try {
          // First try to use userState
          if (userState.userData?.organizationId != null) {
            organizationId.value = userState.userData!.organizationId;
            isLoadingOrgId.value = false;
            logger.d(
              'DEBUG: Using organizationId from userState: ${organizationId.value}',
            );
            return;
          }

          // Fallback: Get from Firebase Auth + Firestore directly
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            logger.d('DEBUG: Current user UID: ${currentUser.uid}');
            final userDoc =
                await FirestoreEnforcer.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .get();

            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>;
              final orgId = userData['organizationId'] as String?;
              organizationId.value = orgId;
              logger.d('DEBUG: Loaded organizationId from Firestore: $orgId');
            } else {
              logger.w('DEBUG: User document does not exist');
            }
          } else {
            logger.w('DEBUG: No current user');
          }
        } catch (e) {
          logger.e('DEBUG: Error loading organizationId: $e', e);
        } finally {
          isLoadingOrgId.value = false;
        }
      }

      loadOrganizationId();
      return null;
    }, [userState.userData?.organizationId]);

    // Load available locations
    useEffect(() {
      if (organizationId.value == null) return null;

      Future<void> loadLocations() async {
        try {
          final locationsSnapshot =
              await FirestoreEnforcer.instance
                  .collection('organizations')
                  .doc(organizationId.value!)
                  .collection('locations')
                  .get();

          availableLocations.value =
              locationsSnapshot.docs.map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  'name':
                      data['locationName'] ?? context.l10n.commonNotSpecified,
                };
              }).toList();
        } catch (e) {
          logger.e('Error loading locations: $e', e);
        }
      }

      loadLocations();
      return null;
    }, [organizationId.value]);

    final categories = [
      'All',
      'Safety Procedures',
      'Cleaning Protocols',
      'Training Materials',
      'Operating Procedures',
      'Emergency Procedures',
      'Equipment Manuals',
      'Policy Documents',
      'Other',
    ];

    // Show loading while we're determining the organizationId
    if (isLoadingOrgId.value) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).primaryColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          title: Row(
            children: [
              HandsIcon(size: 36, enableShadow: false),
              const SizedBox(width: 12),
              Text(
                l10n.documentsTitle,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          centerTitle: false,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
        bottomNavigationBar: BottomNavBar(currentIndex: 4, userRole: userRole),
      );
    }

    // Return error state if no organizationId is available
    if (organizationId.value == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).primaryColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          title: Row(
            children: [
              HandsIcon(size: 36, enableShadow: false),
              const SizedBox(width: 12),
              Text(
                l10n.documentsTitle,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          centerTitle: false,
          elevation: 0,
        ),
        body: Center(child: Text(l10n.documentsNoOrganization)),
        bottomNavigationBar: BottomNavBar(currentIndex: 4, userRole: userRole),
      );
    }

    // Helper: open upload/edit bottom sheet
    void showUploadSheet({String? docId, Map<String, dynamic>? docData}) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
          return UploadDocumentBottomSheet(
            documentId: docId,
            documentData: docData,
            locationId:
                currentLocationId, // Pass the current location ID from LocationSelectionService
            onDocumentUploaded: () {
              // Close the sheet from the parent on the next frame to avoid Navigator lock.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (ctx.mounted && Navigator.of(ctx).canPop()) {
                  Navigator.of(ctx).pop();
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        docId == null
                            ? l10n.documentsUploaded
                            : l10n.documentsUpdated,
                      ),
                    ),
                  );
                }
              });
            },
          );
        },
      );
    }

    // Helper: confirm & delete document
    Future<void> deleteDocument(String docId) async {
      if (organizationId.value == null) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text(l10n.documentsDeleteTitle),
              content: Text(l10n.documentsDeleteBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l10n.commonCancel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text(l10n.commonDelete),
                ),
              ],
            ),
      );
      if (confirmed != true) return;
      if (!context.mounted) return;

      try {
        await FirestoreEnforcer.instance
            .collection('organizations')
            .doc(organizationId.value!)
            .collection('training_documents')
            .doc(docId)
            .delete();
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.documentsDeletedSuccess)));
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.documentsDeleteError(e.toString()))),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: HandsColors.cardPrimary,
        elevation: 0,
        toolbarHeight: kToolbarHeight,
        title: GenericAppBarContent(
          appBarTitle: l10n.documentsTitle,
          userRole: userRole,
        ),
        automaticallyImplyLeading: false,
        actions: [
          UnifiedMenuButton(
            userRole: userRole,
            organizationId: organizationId.value,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF07090D), Color(0xFF0F131A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                children: [
                  HandsModalSection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.documentsTitle,
                                    style: GoogleFonts.inter(
                                      fontSize: 29,
                                      fontWeight: FontWeight.w800,
                                      color: HandsColors.white,
                                      letterSpacing: -0.7,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    userRole == 2
                                        ? l10n.documentsAdminSubtitle
                                        : l10n.documentsStaffSubtitle,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: HandsColors.white70,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ContextHelpTrigger(
                              title: l10n.documentsTitle,
                              subtitle: l10n.documentsHelpSubtitle,
                              topicIds: [
                                'staff-document-center',
                                'admin-document-center',
                              ],
                            ),
                            if (userRole == 2) ...[
                              const SizedBox(width: 16),
                              HandsPrimaryButton(
                                text: l10n.documentsUpload,
                                icon: Icons.cloud_upload_outlined,
                                onPressed: () => showUploadSheet(),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          onChanged: (value) => searchQuery.value = value,
                          style: GoogleFonts.inter(
                            color: HandsColors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: l10n.documentsSearchHint,
                            hintStyle: GoogleFonts.inter(
                              color: HandsColors.white30,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: HandsColors.white70,
                              size: 18,
                            ),
                            filled: true,
                            fillColor: HandsModalTokens.surfaceMuted,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: HandsModalTokens.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: HandsModalTokens.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: HandsModalTokens.accent,
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children:
                                categories.map((category) {
                                  final isSelected =
                                      selectedCategory.value == category;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(
                                        localizedDocumentCategoryLabel(
                                          context,
                                          category,
                                        ),
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              isSelected
                                                  ? HandsColors.white
                                                  : HandsColors.white70,
                                        ),
                                      ),
                                      selected: isSelected,
                                      onSelected:
                                          (_) =>
                                              selectedCategory.value = category,
                                      backgroundColor:
                                          HandsColors.secondaryContainer,
                                      selectedColor: HandsColors.handsOrange,
                                      side: BorderSide(
                                        color:
                                            isSelected
                                                ? HandsColors.handsOrange
                                                : HandsColors.white12,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (availableLocations.value.length > 1) ...[
                    const SizedBox(height: 12),
                    HandsModalSection(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: HandsColors.handsOrange.withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.location_on_outlined,
                              color: HandsColors.handsOrange,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.documentsCurrentScope,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: HandsColors.white70,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  getCurrentLocationName(),
                                  style: GoogleFonts.inter(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                    color: HandsColors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: HandsColors.secondaryContainer,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: HandsColors.white12),
                            ),
                            child: Text(
                              l10n.documentsLocationsCount(
                                availableLocations.value.length,
                              ),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: HandsColors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getDocumentsStream(
                  organizationId.value!,
                  selectedCategory.value,
                  currentLocationId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        l10n.documentsErrorLoading(snapshot.error.toString()),
                        style: GoogleFonts.inter(color: HandsColors.white70),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return _buildEmptyState(context, userRole, showUploadSheet);
                  }

                  final snapshotData = snapshot.data;
                  if (snapshotData == null || snapshotData.docs.isEmpty) {
                    return _buildEmptyState(context, userRole, showUploadSheet);
                  }

                  final allDocs = snapshotData.docs;

                  final locationScopedDocs =
                      allDocs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final docLocationId = data['locationId'] as String?;
                        final selectedLoc = currentLocationId;
                        if (selectedLoc == null) return true;
                        return docLocationId == selectedLoc;
                      }).toList();

                  final normalizedSearch =
                      searchQuery.value.trim().toLowerCase();
                  final docs =
                      locationScopedDocs.where((doc) {
                        if (normalizedSearch.isEmpty) return true;
                        final data = doc.data() as Map<String, dynamic>;
                        final title =
                            (data['title'] as String? ?? '').toLowerCase();
                        final category =
                            (data['category'] as String? ?? '').toLowerCase();
                        final fileName =
                            (data['fileName'] as String? ?? '').toLowerCase();
                        return title.contains(normalizedSearch) ||
                            category.contains(normalizedSearch) ||
                            fileName.contains(normalizedSearch);
                      }).toList();

                  if (kDebugMode) {
                    print(
                      '[TrainingMaterials] Visible documents: ${docs.length}',
                    );
                  }

                  if (docs.isEmpty) {
                    return _buildFilteredEmptyState(
                      context,
                      selectedCategory.value,
                      searchQuery.value,
                    );
                  }

                  final categoriesRepresented =
                      docs
                          .map(
                            (doc) =>
                                (doc.data() as Map<String, dynamic>)['category']
                                    as String? ??
                                'Other',
                          )
                          .toSet()
                          .length;

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _DocumentMetricCard(
                                label: l10n.documentsVisibleFiles,
                                value: '${docs.length}',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DocumentMetricCard(
                                label: l10n.documentsCategories,
                                value: '$categoriesRepresented',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DocumentMetricCard(
                                label: l10n.documentsScope,
                                value:
                                    currentLocationId == null
                                        ? l10n.documentsScopeAll
                                        : l10n.documentsScopeLocal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 960;
                              if (isWide) {
                                return GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        childAspectRatio: 2.3,
                                      ),
                                  itemCount: docs.length,
                                  itemBuilder: (context, index) {
                                    final doc = docs[index];
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    return _DocumentCard(
                                      data: data,
                                      userRole: userRole,
                                      onEdit:
                                          userRole == 2
                                              ? () => showUploadSheet(
                                                docId: doc.id,
                                                docData: data,
                                              )
                                              : null,
                                      onDelete:
                                          userRole == 2
                                              ? () => deleteDocument(doc.id)
                                              : null,
                                      onOpen:
                                          () => _openDocument(
                                            context,
                                            data,
                                            userRole,
                                          ),
                                    );
                                  },
                                );
                              }

                              return ListView.separated(
                                itemCount: docs.length,
                                separatorBuilder:
                                    (_, _) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final doc = docs[index];
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  return _DocumentCard(
                                    data: data,
                                    userRole: userRole,
                                    onEdit:
                                        userRole == 2
                                            ? () => showUploadSheet(
                                              docId: doc.id,
                                              docData: data,
                                            )
                                            : null,
                                    onDelete:
                                        userRole == 2
                                            ? () => deleteDocument(doc.id)
                                            : null,
                                    onOpen:
                                        () => _openDocument(
                                          context,
                                          data,
                                          userRole,
                                        ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: 4, userRole: userRole),
    );
  }

  Future<void> _openDocument(
    BuildContext context,
    Map<String, dynamic> data,
    int userRole,
  ) async {
    final title = data['title'] ?? context.l10n.documentsUntitled;
    final type = data['fileType'] ?? 'document';
    final url = data['fileUrl'] ?? '';
    final fileName = data['fileName'] ?? '';

    if (url.isEmpty) return;

    if (!kIsWeb &&
        (fileName?.toLowerCase().endsWith('.pdf') == true ||
            type.toLowerCase() == 'document')) {
      try {
        final uri = Uri.parse(url);
        final success = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (!success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.documentsOpenError),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.documentsOpenErrorDetailed(e.toString()),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => DocumentViewerPage(
                url: url,
                title: title,
                fileType: type,
                fileName: fileName,
                userRole: userRole,
              ),
        ),
      );
    }
  }

  Stream<QuerySnapshot> _getDocumentsStream(
    String organizationId,
    String category,
    String? locationId,
  ) {
    logger.d(
      'DEBUG: Getting documents for orgId: $organizationId, category: $category, locationId: $locationId',
    );
    logger.d(
      'DEBUG: Full path: organizations/$organizationId/training_documents',
    );

    // Updated path to match admin dashboard's nested path structure
    Query query = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(organizationId)
        .collection('training_documents');

    // Do NOT filter by location in Firestore so we can include global docs (missing/empty locationId) client-side
    // Filtering by location here would exclude global documents from results.

    if (category != 'All') {
      logger.d('DEBUG: Filtering by category: $category');
      query = query.where('category', isEqualTo: category);
      // Re-enable orderBy with category filter
      query = query.orderBy('createdAt', descending: true);
    } else {
      logger.d('DEBUG: No category filter, getting all documents');
      // For "All" category, try without orderBy first
      // query = query.orderBy('createdAt', descending: true);
    }

    return query
        .snapshots()
        .map((snapshot) {
          logger.d('DEBUG: Query executed successfully');
          logger.d('DEBUG: Found ${snapshot.docs.length} documents');

          if (snapshot.docs.isEmpty) {
            logger.d(
              'DEBUG: No documents found - checking if collection exists',
            );
          }

          for (var doc in snapshot.docs) {
            logger.d('DEBUG: Document ${doc.id}: ${doc.data()}');
          }
          return snapshot;
        })
        .handleError((error) {
          logger.e('DEBUG: Stream error: $error', error);
          logger.d('DEBUG: Error type: ${error.runtimeType}');
        });
  }

  Widget _buildEmptyState(
    BuildContext context,
    int userRole,
    VoidCallback showUploadSheet,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: HandsModalSection(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color:
                      userRole == 2
                          ? HandsColors.handsOrange.withValues(alpha: 0.14)
                          : HandsColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  userRole == 2
                      ? Icons.cloud_upload_outlined
                      : Icons.menu_book_outlined,
                  size: 30,
                  color:
                      userRole == 2
                          ? HandsColors.handsOrange
                          : HandsColors.white70,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                userRole == 2
                    ? context.l10n.documentsBuildLibraryTitle
                    : context.l10n.documentsNoDocumentsTitle,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: HandsColors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                userRole == 2
                    ? context.l10n.documentsBuildLibraryBody
                    : context.l10n.documentsNoDocumentsBody,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: HandsColors.white70,
                  height: 1.45,
                ),
              ),
              if (userRole == 2) ...[
                const SizedBox(height: 18),
                HandsPrimaryButton(
                  text: context.l10n.documentsUploadFirst,
                  icon: Icons.add,
                  onPressed: showUploadSheet,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilteredEmptyState(
    BuildContext context,
    String category,
    String query,
  ) {
    final hasSearch = query.trim().isNotEmpty;
    final message =
        hasSearch
            ? context.l10n.documentsNoMatches(query)
            : category == 'All'
            ? context.l10n.documentsNoLocationDocs
            : context.l10n.documentsNoCategoryDocs(
              localizedDocumentCategoryLabel(context, category),
            );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: HandsModalSection(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.find_in_page_outlined,
                size: 34,
                color: HandsColors.white70,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.documentsNothingToShow,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: HandsColors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: HandsColors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentMetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _DocumentMetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return HandsModalSection(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: HandsColors.white70,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: HandsColors.white,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final int userRole;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _DocumentCard({
    required this.data,
    required this.userRole,
    required this.onOpen,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] as String?) ?? context.l10n.documentsUntitled;
    final type = (data['fileType'] as String?) ?? 'document';
    final category = (data['category'] as String?) ?? 'Other';
    final fileName = (data['fileName'] as String?) ?? '';
    final locationId = data['locationId'] as String?;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    final icon = switch (type.toLowerCase()) {
      'video' => Icons.videocam_outlined,
      'image' => Icons.image_outlined,
      _ => Icons.description_outlined,
    };

    final typeLabel = switch (type.toLowerCase()) {
      'video' => context.l10n.documentsTypeVideo,
      'image' => context.l10n.documentsTypeImage,
      _ => context.l10n.documentsTypeDoc,
    };

    final accent = switch (type.toLowerCase()) {
      'video' => const Color(0xFF57B7FF),
      'image' => HandsColors.sageGreen,
      _ => HandsColors.handsOrange,
    };

    return HandsModalSection(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: HandsColors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _DocumentTag(
                            label: localizedDocumentCategoryLabel(
                              context,
                              category,
                            ),
                          ),
                          _DocumentTag(label: typeLabel, accent: accent),
                          _DocumentTag(
                            label:
                                locationId == null
                                    ? context.l10n.documentsGlobal
                                    : context.l10n.documentsLocation,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (userRole == 2) ...[
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: HandsColors.white70,
                    ),
                    tooltip: context.l10n.documentsEditTooltip,
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: HandsColors.error,
                    ),
                    tooltip: context.l10n.documentsDeleteTooltip,
                  ),
                ] else
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: HandsColors.white30,
                  ),
              ],
            ),
            if (fileName.isNotEmpty || createdAt != null) ...[
              const SizedBox(height: 12),
              Text(
                fileName.isNotEmpty
                    ? fileName
                    : context.l10n.documentsAddedDate(
                      MaterialLocalizations.of(
                        context,
                      ).formatShortDate(createdAt!),
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: HandsColors.white70,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DocumentTag extends StatelessWidget {
  final String label;
  final Color? accent;

  const _DocumentTag({required this.label, this.accent});

  @override
  Widget build(BuildContext context) {
    final color = accent ?? HandsColors.white70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color:
            accent == null
                ? HandsColors.secondaryContainer
                : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color:
              accent == null
                  ? HandsColors.white12
                  : color.withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class DocumentViewerPage extends HookWidget {
  final String url;
  final String title;
  final String fileType;
  final int userRole;
  final String? fileName;

  const DocumentViewerPage({
    super.key,
    required this.url,
    required this.title,
    required this.fileType,
    required this.userRole,
    this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isLoading = useState(true);
    final errorMessage = useState<String?>(null);
    final localPath = useState<String?>(null);

    Future<String?> downloadAndCacheFile() async {
      try {
        // Validate URL first
        if (url.isEmpty) {
          throw Exception(l10n.documentsViewerNoPath);
        }

        final uri = Uri.tryParse(url);
        if (uri == null) {
          throw Exception(l10n.documentsViewerInvalidUrl);
        }

        debugPrint('[DocumentViewer] Processing URL: $url');
        debugPrint(
          '[DocumentViewer] File type: $fileType, Platform: ${kIsWeb ? 'web' : 'mobile'}',
        );

        // For web platform, we just return the URL for direct access
        if (kIsWeb) {
          return url;
        }

        // For mobile platforms, download and cache the file locally for native viewing
        final response = await http.get(uri);
        if (response.statusCode != 200) {
          throw Exception(l10n.documentsViewerDownloadFailed);
        }

        final documentsDir = await getApplicationDocumentsDirectory();
        final filename =
            fileName?.isNotEmpty == true
                ? fileName!.replaceAll(RegExp(r'[^\w\s\-_\.]'), '_')
                : 'document_${DateTime.now().millisecondsSinceEpoch}.pdf';

        final localFile = File('${documentsDir.path}/$filename');
        await localFile.writeAsBytes(response.bodyBytes);

        debugPrint('[DocumentViewer] Downloaded to: ${localFile.path}');
        return localFile.path;
      } catch (e) {
        debugPrint('Error in downloadAndCacheFile: $e');
        throw Exception(e.toString());
      }
    }

    useEffect(() {
      downloadAndCacheFile()
          .then((path) {
            localPath.value = path;
            isLoading.value = false;
          })
          .catchError((error) {
            errorMessage.value = error.toString();
            isLoading.value = false;
          });
      return null;
    }, [url]);

    Future<void> openInBrowser() async {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: openInBrowser,
            tooltip: context.l10n.documentsViewerOpenExternalTooltip,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () async {
              final uri = Uri.parse(url);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            tooltip: context.l10n.documentsViewerDownloadTooltip,
          ),
        ],
      ),
      body:
          isLoading.value
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(context.l10n.documentsViewerLoading),
                  ],
                ),
              )
              : errorMessage.value != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.documentsViewerErrorTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorMessage.value!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (url.isNotEmpty) ...[
                      Text(
                        '${context.l10n.documentsViewerDocumentUrl} ${url.length > 100 ? '${url.substring(0, 100)}...' : url}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade500,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Wrap(
                      spacing: 12,
                      children: [
                        ElevatedButton.icon(
                          onPressed: openInBrowser,
                          icon: const Icon(Icons.open_in_browser),
                          label: Text(context.l10n.documentsViewerTestBrowser),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            // Retry loading
                            isLoading.value = true;
                            errorMessage.value = null;
                            downloadAndCacheFile()
                                .then((path) {
                                  localPath.value = path;
                                  isLoading.value = false;
                                })
                                .catchError((error) {
                                  errorMessage.value = error.toString();
                                  isLoading.value = false;
                                });
                          },
                          icon: const Icon(Icons.refresh),
                          label: Text(context.l10n.documentsViewerRetry),
                        ),
                      ],
                    ),
                  ],
                ),
              )
              : _buildDocumentViewer(context, localPath.value),
      // Use userRole from constructor parameter
      bottomNavigationBar: BottomNavBar(currentIndex: 4, userRole: userRole),
    );
  }

  Widget _buildDocumentViewer(BuildContext context, String? path) {
    if (path == null) {
      return Center(child: Text(context.l10n.documentsViewerNoPath));
    }

    final lowerType = fileType.toLowerCase();
    final ext = _inferExtension();
    final isPdf = ext == 'pdf';
    final isDoc = ext == 'doc' || ext == 'docx';
    debugPrint(
      '[DocumentViewer] type=$lowerType, ext=$ext, isWeb=$kIsWeb, isDoc=$isDoc, isPdf=$isPdf',
    );
    switch (lowerType) {
      case 'document':
        if (kIsWeb && isDoc) {
          return _buildOfficeDocViewerWeb(context, path);
        }
        return _buildPDFViewer(context, path);
      case 'image':
        return _buildImageViewer(path);
      case 'video':
        return _buildVideoViewer(context, path);
      default:
        return _buildUnsupportedViewer(context);
    }
  }

  String _inferExtension() {
    // Prefer explicit fileName when present
    if ((fileName != null) && fileName!.contains('.')) {
      final parts = fileName!.split('.');
      return parts.isNotEmpty ? parts.last.toLowerCase() : '';
    }
    // Fallback: try to parse from URL path (Firebase Storage keeps original name in path)
    try {
      final uri = Uri.parse(url);
      if (uri.pathSegments.isNotEmpty) {
        final lastSeg = Uri.decodeComponent(uri.pathSegments.last);
        if (lastSeg.contains('.')) {
          return lastSeg.split('.').last.toLowerCase();
        }
      }
    } catch (_) {}
    return '';
  }

  Widget _buildPDFViewer(BuildContext context, String path) {
    // For mobile platforms, use native system viewer directly
    if (!kIsWeb) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Document icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.picture_as_pdf,
                size: 80,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 32),

            // Title
            Text(
              context.l10n.documentsViewerTrainingDocument,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              context.l10n.documentsViewerNativeBody,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            // Primary action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final uri = Uri.parse(path);
                    final success = await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );

                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.documentsOpenError),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.l10n.documentsOpenErrorDetailed(
                              e.toString(),
                            ),
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 24),
                label: Text(
                  context.l10n.documentsViewerOpenDocument,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Help text
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.documentsViewerNativeHelp,
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // For web, use the existing web approach
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Document icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Icon(
                      Icons.picture_as_pdf,
                      size: 80,
                      color: Colors.red.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Document title
                  Text(
                    context.l10n.documentsViewerPdfTitle,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Info text
                  Text(
                    context.l10n.documentsViewerWebBody,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Action buttons
                  Column(
                    children: [
                      // Primary action - View in new tab
                      SizedBox(
                        width: 250,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(path);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          icon: const Icon(Icons.open_in_new, size: 20),
                          label: Text(context.l10n.documentsViewerViewDocument),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Secondary actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _copyUrlToClipboard(context, path),
                            icon: const Icon(Icons.copy, size: 18),
                            label: Text(context.l10n.documentsViewerCopyLink),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final uri = Uri.parse(path);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                            icon: const Icon(Icons.download, size: 18),
                            label: Text(
                              context.l10n.documentsViewerDownloadTooltip,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Technical info for troubleshooting
                  const SizedBox(height: 32),
                  ExpansionTile(
                    title: Text(
                      context.l10n.documentsViewerTechnicalInfo,
                      style: const TextStyle(fontSize: 14),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.documentsViewerDocumentUrl,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              path,
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              context.l10n.documentsViewerNewTabNote,
                              style: const TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficeDocViewerWeb(BuildContext context, String path) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Document icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Icon(
                      Icons.description,
                      size: 80,
                      color: Colors.blue.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Document title
                  Text(
                    context.l10n.documentsViewerOfficeTitle,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Info text
                  Text(
                    context.l10n.documentsViewerWebBody,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Action buttons
                  Column(
                    children: [
                      // Primary action - View in new tab
                      SizedBox(
                        width: 250,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(path);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          icon: const Icon(Icons.open_in_new, size: 20),
                          label: Text(context.l10n.documentsViewerViewDocument),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Secondary actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _copyUrlToClipboard(context, path),
                            icon: const Icon(Icons.copy, size: 18),
                            label: Text(context.l10n.documentsViewerCopyLink),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final uri = Uri.parse(path);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                            icon: const Icon(Icons.download, size: 18),
                            label: Text(
                              context.l10n.documentsViewerDownloadTooltip,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Technical info for troubleshooting
                  const SizedBox(height: 32),
                  ExpansionTile(
                    title: Text(
                      context.l10n.documentsViewerTechnicalInfo,
                      style: const TextStyle(fontSize: 14),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.documentsViewerDocumentUrl,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              path,
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              context.l10n.documentsViewerNewTabNote,
                              style: const TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageViewer(String url) {
    return InteractiveViewer(
      panEnabled: true,
      boundaryMargin: const EdgeInsets.all(20),
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value:
                    loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(context.l10n.documentsViewerImageFailed),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVideoViewer(BuildContext context, String url) {
    // Use the existing VideoPlayerWidget for all platforms to keep UI consistent.
    return VideoPlayerWidget(url: url);
  }

  Widget _buildUnsupportedViewer(BuildContext context) {
    return Builder(
      builder:
          (context) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.insert_drive_file,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.documentsViewerPreviewUnavailable,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.documentsViewerUnsupportedPreview,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_browser),
                  label: Text(context.l10n.documentsViewerOpenExternal),
                ),
              ],
            ),
          ),
    );
  }

  void _copyUrlToClipboard(BuildContext context, String url) async {
    try {
      // Use Flutter's universal Clipboard for all platforms
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.documentsViewerUrlCopied)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.documentsViewerCopyFailed)),
        );
      }
    }
  }
}

class VideoPlayerWidget extends HookWidget {
  final String url;

  const VideoPlayerWidget({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final videoController = useState<VideoPlayerController?>(null);
    final isInitialized = useState(false);
    final isPlaying = useState(false);
    final hasError = useState(false);

    useEffect(() {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      videoController.value = controller;

      controller
          .initialize()
          .then((_) {
            isInitialized.value = true;
          })
          .catchError((error) {
            hasError.value = true;
            // Handle video initialization error silently or use a proper logging framework
          });

      controller.addListener(() {
        isPlaying.value = controller.value.isPlaying;
      });

      return () {
        controller.dispose();
      };
    }, [url]);

    if (hasError.value) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(context.l10n.documentsViewerVideoFailed),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_browser),
              label: Text(context.l10n.documentsViewerOpenExternal),
            ),
          ],
        ),
      );
    }

    if (!isInitialized.value || videoController.value == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(context.l10n.documentsViewerLoadingVideo),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: videoController.value!.value.aspectRatio,
              child: VideoPlayer(videoController.value!),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  if (isPlaying.value) {
                    videoController.value!.pause();
                  } else {
                    videoController.value!.play();
                  }
                },
                icon: Icon(
                  isPlaying.value ? Icons.pause : Icons.play_arrow,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: VideoProgressIndicator(
                  videoController.value!,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
