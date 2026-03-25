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

class ViewDocumentsPage extends HookConsumerWidget {
  const ViewDocumentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userStateProvider);

    // Get userRole from multiple sources with fallback
    int userRole = userState.userData?.userRole ?? 0;

    // Check for GoRouter extra parameter (from bottom nav)
    final routeExtra = GoRouterState.of(context).extra;
    if (routeExtra is Map<String, dynamic> && routeExtra.containsKey('userRole')) {
      userRole = routeExtra['userRole'] as int? ?? userRole;
    }

    // Check for navigation argument (legacy support)
    final navArgs = ModalRoute.of(context)?.settings.arguments;
    if (navArgs is int) {
      userRole = navArgs;
    }

    final selectedCategory = useState<String>('All');
    final organizationId = useState<String?>(null);
    final isLoadingOrgId = useState<bool>(true);
    final availableLocations = useState<List<Map<String, dynamic>>>([]);

    // Use LocationSelectionService instead of local state
    final currentLocationId = useValueListenable(LocationSelectionService.instance.listenable);

    // Helper to get current location name
    String getCurrentLocationName() {
      if (currentLocationId == null) return 'All Locations';
      try {
        final match = availableLocations.value.firstWhere(
          (l) => l['id'] == currentLocationId,
          orElse: () => <String, dynamic>{},
        );
        return match.isNotEmpty ? match['name'] as String : 'Unknown Location';
      } catch (_) {
        return 'Unknown Location';
      }
    }

    logger.d('DEBUG: userState: $userState');
    logger.d('DEBUG: userState.userData: ${userState.userData}');
    logger.d('DEBUG: organizationId from userState: ${userState.userData?.organizationId}');
    debugPrint('DEBUG: organizationId from useState: ${organizationId.value}');

    // Fallback mechanism to get organizationId directly from Firebase Auth/Firestore
    useEffect(() {
      Future<void> loadOrganizationId() async {
        try {
          // First try to use userState
          if (userState.userData?.organizationId != null) {
            organizationId.value = userState.userData!.organizationId;
            isLoadingOrgId.value = false;
            logger.d('DEBUG: Using organizationId from userState: ${organizationId.value}');
            return;
          }

          // Fallback: Get from Firebase Auth + Firestore directly
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            logger.d('DEBUG: Current user UID: ${currentUser.uid}');
            final userDoc = await FirestoreEnforcer.instance.collection('users').doc(currentUser.uid).get();

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
                return {'id': doc.id, 'name': data['locationName'] ?? 'Unnamed Location'};
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
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
          iconTheme: const IconThemeData(color: Colors.white),
          title: Row(
            children: const [
              HandsIcon(size: 36, enableShadow: false),
              SizedBox(width: 12),
              Text(
                'Training Materials',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
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
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
          iconTheme: const IconThemeData(color: Colors.white),
          title: Row(
            children: const [
              HandsIcon(size: 36, enableShadow: false),
              SizedBox(width: 12),
              Text(
                'Training Materials',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ],
          ),
          centerTitle: false,
          elevation: 0,
        ),
        body: const Center(child: Text('No organization found. Please contact support.')),
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
            locationId: currentLocationId, // Pass the current location ID from LocationSelectionService
            onDocumentUploaded: () {
              // Close the sheet from the parent on the next frame to avoid Navigator lock.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (ctx.mounted && Navigator.of(ctx).canPop()) {
                  Navigator.of(ctx).pop();
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(docId == null ? 'Document uploaded' : 'Document updated')));
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
              title: const Text('Delete Document'),
              content: const Text('Are you sure you want to delete this document? This action cannot be undone.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document deleted successfully')));
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting document: $e')));
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: HandsColors.cardPrimary,
        elevation: 0,
        toolbarHeight: kToolbarHeight,
        title: GenericAppBarContent(appBarTitle: 'Training Materials', userRole: userRole),
        automaticallyImplyLeading: false,
        actions: [UnifiedMenuButton(userRole: userRole, organizationId: organizationId.value)],
      ),
      floatingActionButton:
          userRole == 2
              ? FloatingActionButton.extended(
                onPressed: () => showUploadSheet(),
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Upload'),
              )
              : null,
      body: Column(
        children: [
          // Location indicator (only show if multiple locations exist)
          if (availableLocations.value.length > 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: HandsColors.cardPrimary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HandsColors.handsOrange.withOpacity(0.3), width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: HandsColors.handsOrange, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Location',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: HandsColors.white70),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          getCurrentLocationName(),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: HandsColors.white),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: HandsColors.handsOrange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: HandsColors.handsOrange.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${availableLocations.value.length} locations',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: HandsColors.handsOrange),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Category Filter
          Container(
            height: 42,
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = selectedCategory.value == category;

                return ChoiceChip(
                  label: Text(
                    category,
                    style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400),
                  ),
                  selected: isSelected,
                  onSelected: (_) => selectedCategory.value = category,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          // Documents List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getDocumentsStream(organizationId.value!, selectedCategory.value, currentLocationId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error loading documents: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return _buildEmptyState(context, userRole, showUploadSheet);
                }

                final snapshotData = snapshot.data;
                if (snapshotData == null || snapshotData.docs.isEmpty) {
                  return _buildEmptyState(context, userRole, showUploadSheet);
                }

                // Apply client-side location filtering
                final allDocs = snapshotData.docs;

                if (kDebugMode) {
                  print('[TrainingMaterials] Total documents retrieved: ${allDocs.length}');
                  print('[TrainingMaterials] Selected location ID: $currentLocationId');
                  for (var doc in allDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    print(
                      '[TrainingMaterials] Document ${doc.id}: locationId=${data['locationId']}, title=${data['title']}',
                    );
                  }
                }

                final docs =
                    allDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final docLocationId = data['locationId'] as String?;
                      final selectedLoc = currentLocationId;

                      // If "All Locations" is selected (selectedLoc is null), show all documents
                      if (selectedLoc == null) {
                        return true;
                      }

                      // If a specific location is selected, only show documents for that location
                      // Documents without a locationId are treated as unassigned and won't show unless "All" is selected
                      return docLocationId == selectedLoc;
                    }).toList();

                if (kDebugMode) {
                  print('[TrainingMaterials] Filtered documents: ${docs.length}');
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final title = data['title'] ?? 'Untitled';
                    final type = data['fileType'] ?? 'document';
                    final url = data['fileUrl'] ?? '';
                    final subtitle = data['category'] ?? '';
                    final fileName = data['fileName'] ?? '';

                    IconData icon;
                    switch (type.toLowerCase()) {
                      case 'document':
                        icon = Icons.picture_as_pdf;
                        break;
                      case 'video':
                        icon = Icons.videocam;
                        break;
                      case 'image':
                        icon = Icons.image;
                        break;
                      default:
                        icon = Icons.insert_drive_file;
                        break;
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: Icon(icon, size: 24, color: Theme.of(context).primaryColor),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subtitle,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (fileName.isNotEmpty)
                              Text(
                                fileName,
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (userRole == 2) ...[
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                tooltip: 'Edit',
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: () => showUploadSheet(docId: doc.id, docData: data),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18),
                                tooltip: 'Delete',
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: () => deleteDocument(doc.id),
                              ),
                            ],
                            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
                          ],
                        ),
                        onTap:
                            url.isNotEmpty
                                ? () async {
                                  // Quick fix: For PDFs on mobile, use native system viewer
                                  if (!kIsWeb &&
                                      (fileName?.toLowerCase().endsWith('.pdf') == true ||
                                          type.toLowerCase() == 'document')) {
                                    try {
                                      final uri = Uri.parse(url);
                                      final success = await launchUrl(uri, mode: LaunchMode.externalApplication);

                                      if (!success && context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Could not open document. Please check your internet connection.',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error opening document: ${e.toString()}'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  } else {
                                    // Fallback to original viewer for other types
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
                                : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: 4, userRole: userRole),
    );
  }

  Stream<QuerySnapshot> _getDocumentsStream(String organizationId, String category, String? locationId) {
    logger.d('DEBUG: Getting documents for orgId: $organizationId, category: $category, locationId: $locationId');
    logger.d('DEBUG: Full path: organizations/$organizationId/training_documents');

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
            logger.d('DEBUG: No documents found - checking if collection exists');
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

  Widget _buildEmptyState(BuildContext context, int userRole, VoidCallback showUploadSheet) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Role-based icon and content
            if (userRole != 2) ...[
              // Regular users
              const Icon(Icons.folder_open, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                "No training materials available yet.",
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "Your manager or admin will upload training guides, checklists, and helpful documents here.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ] else ...[
              // Admin users (userRole == 2)
              const Icon(Icons.upload_file, size: 64, color: Colors.blueGrey),
              const SizedBox(height: 16),
              Text(
                "No training or documents uploaded yet.",
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "Get started by uploading materials your team needs:\n• Step-by-step training guides\n• Safety procedures and compliance documents\n• Operations manuals and checklists\n• Quick reference files for new hires",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: showUploadSheet,
                icon: const Icon(Icons.add),
                label: const Text("Add New"),
              ),
            ],
          ],
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
    final isLoading = useState(true);
    final errorMessage = useState<String?>(null);
    final localPath = useState<String?>(null);

    Future<String?> downloadAndCacheFile() async {
      try {
        // Validate URL first
        if (url.isEmpty) {
          throw Exception('Document URL is empty');
        }

        final uri = Uri.tryParse(url);
        if (uri == null) {
          throw Exception('Invalid document URL format');
        }

        debugPrint('[DocumentViewer] Processing URL: $url');
        debugPrint('[DocumentViewer] File type: $fileType, Platform: ${kIsWeb ? 'web' : 'mobile'}');

        // For web platform, we just return the URL for direct access
        if (kIsWeb) {
          return url;
        }

        // For mobile platforms, download and cache the file locally for native viewing
        final response = await http.get(uri);
        if (response.statusCode != 200) {
          throw Exception('Failed to download document: HTTP ${response.statusCode}');
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
        throw Exception('Failed to download document: ${e.toString()}');
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
            tooltip: 'Open in external app',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () async {
              final uri = Uri.parse(url);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            tooltip: 'Download',
          ),
        ],
      ),
      body:
          isLoading.value
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Loading document...')],
                ),
              )
              : errorMessage.value != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading document', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      errorMessage.value!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    if (url.isNotEmpty) ...[
                      Text(
                        'URL: ${url.length > 100 ? '${url.substring(0, 100)}...' : url}',
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500, fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Wrap(
                      spacing: 12,
                      children: [
                        ElevatedButton.icon(
                          onPressed: openInBrowser,
                          icon: const Icon(Icons.open_in_browser),
                          label: const Text('Test URL in Browser'),
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
                          label: const Text('Retry'),
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
      return const Center(child: Text('No document path available'));
    }

    final lowerType = fileType.toLowerCase();
    final ext = _inferExtension();
    final isPdf = ext == 'pdf';
    final isDoc = ext == 'doc' || ext == 'docx';
    debugPrint('[DocumentViewer] type=$lowerType, ext=$ext, isWeb=$kIsWeb, isDoc=$isDoc, isPdf=$isPdf');
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
              decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(50)),
              child: Icon(Icons.picture_as_pdf, size: 80, color: Colors.red.shade600),
            ),
            const SizedBox(height: 32),

            // Title
            Text(
              'Training Document',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              'This document will open in your device\'s native viewer for the best experience.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
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
                    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);

                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not open document. Please check your internet connection.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error opening document: ${e.toString()}'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 24),
                label: const Text('Open Document', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      'Documents open in your device\'s built-in viewer for optimal performance and features.',
                      style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
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
                    decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(50)),
                    child: Icon(Icons.picture_as_pdf, size: 80, color: Colors.red.shade600),
                  ),
                  const SizedBox(height: 24),

                  // Document title
                  Text(
                    'PDF Document',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Info text
                  Text(
                    'Click below to view or download this document',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
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
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.open_in_new, size: 20),
                          label: const Text('View Document'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                            label: const Text('Copy Link'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final uri = Uri.parse(path);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Download'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Technical info for troubleshooting
                  const SizedBox(height: 32),
                  ExpansionTile(
                    title: const Text('Technical Information', style: TextStyle(fontSize: 14)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Document URL:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            SelectableText(path, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                            const SizedBox(height: 16),
                            const Text(
                              'Note: Documents open in a new tab due to browser security policies.',
                              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
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
                    decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(50)),
                    child: Icon(Icons.description, size: 80, color: Colors.blue.shade600),
                  ),
                  const SizedBox(height: 24),

                  // Document title
                  Text(
                    'Office Document',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Info text
                  Text(
                    'Click below to view or download this document',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
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
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.open_in_new, size: 20),
                          label: const Text('View Document'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                            label: const Text('Copy Link'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final uri = Uri.parse(path);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Download'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Technical info for troubleshooting
                  const SizedBox(height: 32),
                  ExpansionTile(
                    title: const Text('Technical Information', style: TextStyle(fontSize: 14)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Document URL:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            SelectableText(path, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                            const SizedBox(height: 16),
                            const Text(
                              'Note: Documents open in a new tab due to browser security policies.',
                              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
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
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Failed to load image'),
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
                const Icon(Icons.insert_drive_file, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('Preview not available', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'This file type is not supported for preview',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Open in External App'),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL copied to clipboard')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to copy URL')));
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
            const Text('Failed to load video'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Open in External App'),
            ),
          ],
        ),
      );
    }

    if (!isInitialized.value || videoController.value == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Loading video...')],
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
                icon: Icon(isPlaying.value ? Icons.pause : Icons.play_arrow, size: 32),
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
