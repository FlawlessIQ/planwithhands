import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hands_app/state/user_state.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Ensure userStateProvider is exported from user_state.dart
import 'package:hands_app/global_widgets/bottom_nav_bar.dart';
import 'package:hands_app/global_widgets/generic_app_bar_content.dart';
import 'package:hands_app/global_widgets/unified_menu_button.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/global_widgets/hands_icon.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/ui/UploadDocumentBottomSheet.dart';
import 'package:hands_app/widgets/pdf_inline_viewer.dart';
import 'package:hands_app/services/location_selection_service.dart';
import 'package:hands_app/global_widgets/location_selector.dart' show setCurrentLocation;

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

    // Location selector state
    final selectedLocationId = useState<String?>(null);
    final selectedLocationName = useState<String>('All Locations');
    final availableLocations = useState<List<Map<String, dynamic>>>([]);

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
      Future<void> loadLocations() async {
        if (organizationId.value == null) return;

        try {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser == null) return;

          List<String> locationIds = [];

          if (userRole == 2) {
            // Admin - get all locations
            final locationsSnapshot =
                await FirestoreEnforcer.instance
                    .collection('organizations')
                    .doc(organizationId.value!)
                    .collection('locations')
                    .get();
            locationIds = locationsSnapshot.docs.map((doc) => doc.id).toList();
          } else {
            // Non-admin users: get assigned locations from user document
            final userDoc = await FirestoreEnforcer.instance.collection('users').doc(currentUser.uid).get();

            if (userDoc.exists) {
              final userData = userDoc.data()!;
              if (userData['locationIds'] != null) {
                locationIds = List<String>.from(userData['locationIds']);
              } else if (userData['locationId'] != null) {
                locationIds = [userData['locationId']];
              }
            }
          }

          // Load location details for all locations
          final locations = <Map<String, dynamic>>[];
          for (final locationId in locationIds) {
            final locationDoc =
                await FirestoreEnforcer.instance
                    .collection('organizations')
                    .doc(organizationId.value!)
                    .collection('locations')
                    .doc(locationId)
                    .get();

            if (locationDoc.exists) {
              final data = locationDoc.data()!;
              locations.add({
                'id': locationId,
                'name': data['locationName'] ?? 'Unnamed Location',
                'isPrimary': data['isPrimary'] ?? false,
              });
            }
          }

          // Sort so primary location comes first
          locations.sort((a, b) {
            if (a['isPrimary'] == true && b['isPrimary'] != true) return -1;
            if (b['isPrimary'] == true && a['isPrimary'] != true) return 1;
            return (a['name'] as String).compareTo(b['name'] as String);
          });

          availableLocations.value = locations;

          // Set initial selection to first location if available, or keep "All"
          if (locations.isNotEmpty && selectedLocationId.value == null) {
            selectedLocationId.value = locations.first['id'];
            selectedLocationName.value = locations.first['name'];
          }
        } catch (e) {
          logger.e('Error loading locations: $e');
        }
      }

      if (organizationId.value != null) {
        loadLocations();
      }
      return null;
    }, [organizationId.value, userRole]);

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
            locationId: selectedLocationId.value, // Pass the selected location ID
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
        actions: [
          // Only show location selector if there are multiple locations
          if (availableLocations.value.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: PopupMenuButton<String>(
                onSelected: (value) async {
                  selectedLocationId.value = value;
                  final selected = availableLocations.value.firstWhere(
                    (loc) => loc['id'] == value,
                    orElse: () => <String, String>{'name': 'Unknown Location'},
                  );
                  selectedLocationName.value = selected['name'];

                  // Persist globally so other pages adopt the change
                  try {
                    LocationSelectionService.instance.setLocation(value);
                  } catch (_) {}

                  // Persist to user doc so selection survives across devices
                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      final locRef = FirestoreEnforcer.instance
                          .collection('organizations')
                          .doc(organizationId.value)
                          .collection('locations')
                          .doc(value);
                      await setCurrentLocation(uid: user.uid, locationRef: locRef, locationName: selected['name']);
                      logger.d('[Analytics] location_switch_selected: user=${user.uid}, location=${locRef.id}');
                    }
                  } catch (e) {
                    logger.w('[TrainingMaterials] Failed to persist current location to user doc: $e');
                  }
                },
                itemBuilder:
                    (context) =>
                        availableLocations.value.map((location) {
                          return PopupMenuItem<String>(
                            value: location['id'],
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color:
                                      location['id'] == selectedLocationId.value
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey[600],
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    location['name'],
                                    style: TextStyle(
                                      fontWeight:
                                          location['id'] == selectedLocationId.value
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (location['id'] == selectedLocationId.value)
                                  const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check, size: 16)),
                              ],
                            ),
                          );
                        }).toList(),
                child: Builder(
                  builder: (context) {
                    if (kIsWeb) {
                      // Full web version - show location name
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              selectedLocationName.value.isNotEmpty ? selectedLocationName.value : 'Select Location',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                          ],
                        ),
                      );
                    } else {
                      // Mobile version - just location icon
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                      );
                    }
                  },
                ),
              ),
            ),
          UnifiedMenuButton(userRole: userRole),
        ],
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
          // Category Filter
          Container(
            height: 42,
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
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
              stream: _getDocumentsStream(organizationId.value!, selectedCategory.value, selectedLocationId.value),
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

                final docs = snapshotData.docs;

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
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
                                ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => DocumentViewerPage(
                                            url: url,
                                            title: title,
                                            fileType: type,
                                            userRole: userRole, // Pass userRole to viewer
                                          ),
                                    ),
                                  );
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

    // Filter by location if specified
    if (locationId != null) {
      logger.d('DEBUG: Filtering by locationId: $locationId');
      query = query.where('locationId', isEqualTo: locationId);
    }

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

  const DocumentViewerPage({
    super.key,
    required this.url,
    required this.title,
    required this.fileType,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = useState(true);
    final errorMessage = useState<String?>(null);
    final localPath = useState<String?>(null);

    Future<String?> downloadAndCacheFile() async {
      try {
        // For web platform or any file type, just return URL directly
        if (kIsWeb) {
          return url;
        }

        // For images and videos, we can use the URL directly
        if (fileType.toLowerCase() == 'image') {
          return url;
        }

        // For videos, return the URL directly
        if (fileType.toLowerCase() == 'video') {
          return url;
        }

        // For PDFs on mobile, we'll also just use the URL for now
        // TODO: Implement proper mobile file caching if needed
        return url;
      } catch (e) {
        debugPrint('Error in downloadAndCacheFile: $e');
        // Fallback to direct URL
        return url;
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
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: openInBrowser,
                      icon: const Icon(Icons.open_in_browser),
                      label: const Text('Open in Browser'),
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

    switch (fileType.toLowerCase()) {
      case 'document':
        return _buildPDFViewer(context, path);
      case 'image':
        return _buildImageViewer(path);
      case 'video':
        return _buildVideoViewer(context, path);
      default:
        return _buildUnsupportedViewer(context);
    }
  }

  Widget _buildPDFViewer(BuildContext context, String path) {
    // Use inline viewer on web; fallback to native PDFView elsewhere.
    if (kIsWeb) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(child: PdfInlineViewer(url: path)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(path);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open in New Tab'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return PDFView(
      filePath: path,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: false,
      pageFling: true,
      pageSnap: true,
      defaultPage: 0,
      fitPolicy: FitPolicy.BOTH,
      preventLinkNavigation: false,
      onRender: (pages) {
        debugPrint('PDF rendered with $pages pages');
      },
      onError: (error) {
        debugPrint('PDF error: $error');
      },
      onPageError: (page, error) {
        debugPrint('PDF page $page error: $error');
      },
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
