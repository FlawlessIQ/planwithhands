import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hands_app/state/user_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Ensure userStateProvider is exported from user_state.dart
import 'package:hands_app/global_widgets/bottom_nav_bar.dart';
import 'package:hands_app/global_widgets/unified_menu_button.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hands_app/global_widgets/hands_icon.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

class ViewDocumentsPage extends HookConsumerWidget {
  const ViewDocumentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userStateProvider);
    int userRole = userState.userData?.userRole ?? 0;
    // Check for navigation argument (e.g., passed from admin dashboard)
    final navArgs = ModalRoute.of(context)?.settings.arguments;
    if (navArgs is int) {
      userRole = navArgs;
    }
    final selectedCategory = useState<String>('All');
    final organizationId = useState<String?>(null);
    final isLoadingOrgId = useState<bool>(true);

    print('DEBUG: userState: $userState');
    print('DEBUG: userState.userData: ${userState.userData}');
    print(
      'DEBUG: organizationId from userState: ${userState.userData?.organizationId}',
    );
    print('DEBUG: organizationId from useState: ${organizationId.value}');

    // Fallback mechanism to get organizationId directly from Firebase Auth/Firestore
    useEffect(() {
      Future<void> loadOrganizationId() async {
        try {
          // First try to use userState
          if (userState.userData?.organizationId != null) {
            organizationId.value = userState.userData!.organizationId;
            isLoadingOrgId.value = false;
            print(
              'DEBUG: Using organizationId from userState: ${organizationId.value}',
            );
            return;
          }

          // Fallback: Get from Firebase Auth + Firestore directly
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            print('DEBUG: Current user UID: ${currentUser.uid}');
            final userDoc =
                await FirestoreEnforcer.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .get();

            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>;
              final orgId = userData['organizationId'] as String?;
              organizationId.value = orgId;
              print('DEBUG: Loaded organizationId from Firestore: $orgId');
            } else {
              print('DEBUG: User document does not exist');
            }
          } else {
            print('DEBUG: No current user');
          }
        } catch (e) {
          print('DEBUG: Error loading organizationId: $e');
        } finally {
          isLoadingOrgId.value = false;
        }
      }

      loadOrganizationId();
      return null;
    }, [userState.userData?.organizationId]);

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
            children: const [
              HandsIcon(size: 36, enableShadow: false),
              SizedBox(width: 12),
              Text(
                'Training Materials',
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
            children: const [
              HandsIcon(size: 36, enableShadow: false),
              SizedBox(width: 12),
              Text(
                'Training Materials',
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
        body: const Center(
          child: Text('No organization found. Please contact support.'),
        ),
        bottomNavigationBar: BottomNavBar(currentIndex: 4, userRole: userRole),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: const [
            HandsIcon(size: 36, enableShadow: false),
            SizedBox(width: 12),
            Text(
              'Training Materials',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [UnifiedMenuButton(userRole: userRole)],
        centerTitle: false,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Category Filter
          SizedBox(
            height: 50,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = selectedCategory.value == category;

                return ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (_) => selectedCategory.value = category,
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // Documents List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getDocumentsStream(
                organizationId.value!,
                selectedCategory.value,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading documents: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No documents available.'));
                }

                final docs = snapshot.data!.docs;

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
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
                      child: ListTile(
                        leading: Icon(
                          icon,
                          size: 36,
                          color: Theme.of(context).primaryColor,
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(subtitle),
                            if (fileName.isNotEmpty)
                              Text(
                                fileName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward),
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

  Stream<QuerySnapshot> _getDocumentsStream(
    String organizationId,
    String category,
  ) {
    print(
      'DEBUG: Getting documents for orgId: $organizationId, category: $category',
    );
    print('DEBUG: Full path: organizations/$organizationId/training_documents');

    // Updated path to match admin dashboard's nested path structure
    Query query = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(organizationId)
        .collection('training_documents');

    if (category != 'All') {
      print('DEBUG: Filtering by category: $category');
      query = query.where('category', isEqualTo: category);
      // Re-enable orderBy with category filter
      query = query.orderBy('createdAt', descending: true);
    } else {
      print('DEBUG: No category filter, getting all documents');
      // For "All" category, try without orderBy first
      // query = query.orderBy('createdAt', descending: true);
    }

    return query
        .snapshots()
        .map((snapshot) {
          print('DEBUG: Query executed successfully');
          print('DEBUG: Found ${snapshot.docs.length} documents');

          if (snapshot.docs.isEmpty) {
            print('DEBUG: No documents found - checking if collection exists');
          }

          for (var doc in snapshot.docs) {
            print('DEBUG: Document ${doc.id}: ${doc.data()}');
          }
          return snapshot;
        })
        .handleError((error) {
          print('DEBUG: Stream error: $error');
          print('DEBUG: Error type: ${error.runtimeType}');
        });
  }
}

class DocumentViewerPage extends HookWidget {
  final String url;
  final String title;
  final String fileType;

  const DocumentViewerPage({
    super.key,
    required this.url,
    required this.title,
    required this.fileType,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = useState(true);
    final errorMessage = useState<String?>(null);
    final localPath = useState<String?>(null);

    Future<String?> downloadAndCacheFile() async {
      try {
        // For web platform, return URL directly for all file types
        if (kIsWeb) {
          return url;
        }

        // For images and videos, we can use the URL directly
        if (fileType.toLowerCase() == 'image') {
          return url;
        }

        // For PDFs on mobile, we need to download and cache locally
        if (fileType.toLowerCase() == 'document') {
          try {
            // Use HTTP client instead of Firebase Storage getData for better compatibility
            final http = HttpClient();
            final request = await http.getUrl(Uri.parse(url));
            final response = await request.close();

            if (response.statusCode == 200) {
              final dir = await getTemporaryDirectory();
              final file = File(
                '${dir.path}/temp_document_${DateTime.now().millisecondsSinceEpoch}.pdf',
              );

              final bytes = await consolidateHttpClientResponseBytes(response);
              await file.writeAsBytes(bytes);
              return file.path;
            } else {
              throw Exception(
                'Failed to download PDF: Status ${response.statusCode}',
              );
            }
          } catch (e) {
            // Fallback to direct URL if download fails
            debugPrint('PDF download failed, using direct URL: $e');
            return url;
          }
        }

        // For videos, return the URL directly
        if (fileType.toLowerCase() == 'video') {
          return url;
        }

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
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading document...'),
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
                      'Error loading document',
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
      // Use userRole from userState or default to 0
      bottomNavigationBar: BottomNavBar(
        currentIndex: 4,
        userRole:
            (ModalRoute.of(context)?.settings.arguments is int)
                ? ModalRoute.of(context)!.settings.arguments as int
                : 0,
      ),
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
    // For web, use an iframe or redirect to external viewer
    if (kIsWeb) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              'PDF Preview',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Click below to open the PDF in a new tab',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(path);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open PDF'),
            ),
          ],
        ),
      );
    }

    // For mobile platforms, use the PDFView widget
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
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
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
    // For web, use HTML5 video element which is more reliable
    if (kIsWeb) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: AspectRatio(
                  aspectRatio: 16 / 9, // Default aspect ratio
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: HtmlElementView(
                        viewType: 'video-${url.hashCode}',
                        onPlatformViewCreated: (id) {
                          // Web video element will be created
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open in New Tab'),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: url));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Video URL copied to clipboard'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy URL'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // For mobile, use the existing VideoPlayerWidget
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
                  'Preview not available',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'This file type is not supported for preview',
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
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading video...'),
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
