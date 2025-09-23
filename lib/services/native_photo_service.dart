import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hands_app/services/daily_checklist_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:convert';
// Conditional native IO helpers (macOS) - use platform-specific implementation when available
import 'native_io_stub.dart' if (dart.library.io) 'native_io_macos.dart';
import 'package:hands_app/data/models/task_data.dart';

class NativePhotoService {
  static final ImagePicker _picker = ImagePicker();
  static final DailyChecklistService _checklistService = DailyChecklistService();

  /// Shows native photo options (camera/gallery) and handles upload
  static Future<TaskData?> showPhotoOptions({
    required BuildContext context,
    required TaskData task,
    String? organizationId,
    String? locationId,
    String? checklistId,
  }) async {
    // For web, show a simple dialog with options
    if (kIsWeb) {
      return _showWebPhotoOptions(
        context: context,
        task: task,
        organizationId: organizationId,
        locationId: locationId,
        checklistId: checklistId,
      );
    }

    // For mobile, show native bottom sheet
    return _showMobilePhotoOptions(
      context: context,
      task: task,
      organizationId: organizationId,
      locationId: locationId,
      checklistId: checklistId,
    );
  }

  /// Web-specific photo options
  static Future<TaskData?> _showWebPhotoOptions({
    required BuildContext context,
    required TaskData task,
    String? organizationId,
    String? locationId,
    String? checklistId,
  }) async {
    return showDialog<TaskData?>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Add Photo'),
            content: const Text('Choose photo source:'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              TextButton(
                onPressed:
                    () => _handlePhotoSelection(
                      sheetContext: dialogContext,
                      parentContext: context,
                      source: ImageSource.gallery,
                      task: task,
                      organizationId: organizationId,
                      locationId: locationId,
                      checklistId: checklistId,
                    ),
                child: const Text('Gallery'),
              ),
              if (!kIsWeb) // Camera not reliable on web
                TextButton(
                  onPressed:
                      () => _handlePhotoSelection(
                        sheetContext: dialogContext,
                        parentContext: context,
                        source: ImageSource.camera,
                        task: task,
                        organizationId: organizationId,
                        locationId: locationId,
                        checklistId: checklistId,
                      ),
                  child: const Text('Camera'),
                ),
            ],
          ),
    );
  }

  /// Mobile-specific native bottom sheet
  static Future<TaskData?> _showMobilePhotoOptions({
    required BuildContext context,
    required TaskData task,
    String? organizationId,
    String? locationId,
    String? checklistId,
  }) async {
    final bool hasExistingPhoto = (task.photoUrl?.isNotEmpty == true) || (task.proofImageUrl?.isNotEmpty == true);

    return showModalBottomSheet<TaskData?>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder:
          (sheetContext) => SafeArea(
            child: Wrap(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Photo Options',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                // Options
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.blue),
                  title: const Text('Take Photo'),
                  subtitle: const Text('Use camera to take a new photo'),
                  onTap:
                      () => _handlePhotoSelection(
                        sheetContext: sheetContext,
                        parentContext: context,
                        source: ImageSource.camera,
                        task: task,
                        organizationId: organizationId,
                        locationId: locationId,
                        checklistId: checklistId,
                      ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.green),
                  title: const Text('Choose from Gallery'),
                  subtitle: const Text('Select an existing photo'),
                  onTap:
                      () => _handlePhotoSelection(
                        sheetContext: sheetContext,
                        parentContext: context,
                        source: ImageSource.gallery,
                        task: task,
                        organizationId: organizationId,
                        locationId: locationId,
                        checklistId: checklistId,
                      ),
                ),

                // Show photo if exists
                if (hasExistingPhoto) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.visibility, color: Colors.orange),
                    title: const Text('View Current Photo'),
                    subtitle: const Text('See the current uploaded photo'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showCurrentPhoto(context, task);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Remove Photo'),
                    subtitle: const Text('Delete the current photo'),
                    onTap:
                        () => _handlePhotoRemoval(
                          sheetContext: sheetContext,
                          parentContext: context,
                          task: task,
                          organizationId: organizationId,
                          locationId: locationId,
                          checklistId: checklistId,
                        ),
                  ),
                ],

                // Cancel button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  /// Handle photo selection and upload
  // ignore: use_build_context_synchronously
  static Future<void> _handlePhotoSelection({
    required BuildContext sheetContext,
    required BuildContext parentContext,
    required ImageSource source,
    required TaskData task,
    String? organizationId,
    String? locationId,
    String? checklistId,
  }) async {
    // capture states to avoid BuildContext use across async gaps
    late final NavigatorState parentNav = Navigator.of(parentContext);
    late final NavigatorState sheetNav = Navigator.of(sheetContext);
    late final ScaffoldMessengerState messenger = ScaffoldMessenger.of(parentContext);

    try {
      // Show loading overlay using parent context
      _showLoadingOverlay(parentContext, 'Processing photo...');

      // Pick image with iOS-optimized settings to prevent green coloring
      // The green tint issue on iOS is often caused by HEIC format and color space problems
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 100, // Use 100% quality to preserve color space
        requestFullMetadata: false, // Prevent HEIC color space issues on iOS
      );

      if (image == null) {
        // Close loading and close sheet/dialog returning null
        if (parentNav.canPop()) parentNav.pop();
        if (sheetNav.canPop()) sheetNav.pop(null);
        return;
      }

      // For iOS, ensure we're working with JPEG format to avoid HEIC color space issues
      XFile uploadFile = image;
      try {
        // Read the image bytes
        final imageBytes = await image.readAsBytes();

        // On iOS (detected by file type or when we suspect HEIC issues),
        // create a new JPEG file to ensure proper color space
        if (!kIsWeb &&
            (image.name.toLowerCase().contains('heic') ||
                image.mimeType?.contains('heic') == true ||
                image.path.toLowerCase().contains('heic'))) {
          // Create a temporary JPEG file with proper format
          final tempPath = await nativeWriteTempFile(imageBytes);
          if (tempPath != null) {
            uploadFile = XFile(tempPath, name: 'photo.jpg', mimeType: 'image/jpeg');
          }
        }
        // On macOS, handle file:// paths as before
        else if (nativeIsMacOS && (image.path.startsWith('file://') || image.path.startsWith('/'))) {
          // Normalize path
          final path = image.path.startsWith('file://') ? Uri.parse(image.path).toFilePath() : image.path;
          // Read bytes using native helper
          final bytes = await nativeReadFileBytes(path);
          // Write a temp file that XFile can use (uploadTask reads bytes anyway)
          final tempPath = await nativeWriteTempFile(bytes);
          if (tempPath != null) {
            uploadFile = XFile(tempPath);
          }
        }
      } catch (e) {
        // Fallback: proceed with original XFile; uploadTask may still read bytes
        print('Warning: Could not process image format, using original: $e');
      }

      // Upload via service
      final downloadUrl = await _checklistService.uploadTaskPhoto(
        organizationId: organizationId ?? task.organizationId ?? '',
        locationId: locationId ?? task.locationId ?? '',
        checklistId: checklistId ?? task.checklistId ?? '',
        taskId: task.taskId,
        imageFile: uploadFile,
      );

      // Close loading overlay
      if (parentNav.canPop()) parentNav.pop();

      // Create updated task
      final updatedTask = task.copyWith(photoUrl: downloadUrl, proofImageUrl: downloadUrl);

      // Show success on parent context
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Photo uploaded successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Pop the sheet/dialog with the updated task so callers receive it
      if (sheetNav.canPop()) sheetNav.pop(updatedTask);
    } catch (e) {
      // Close loading if still showing
      try {
        if (parentNav.canPop()) parentNav.pop();
      } catch (_) {}

      final err = e.toString();
      // Detect common local emulator connection problems and give actionable advice
      String userMessage;
      if (err.contains('127.0.0.1') ||
          err.contains('Connection refused') ||
          err.contains('Failed host lookup') ||
          err.contains('ERR_CONNECTION_REFUSED')) {
        userMessage =
            'Unable to reach the Firebase Storage emulator at 127.0.0.1:9199.\nStart the emulator (e.g. `firebase emulators:start --only storage`) or switch to production Storage in your web config.';
      } else {
        userMessage = 'Error uploading photo: $err';
      }

      // Show error
      try {
        messenger.showSnackBar(
          SnackBar(content: Text(userMessage), backgroundColor: Colors.red, duration: const Duration(seconds: 6)),
        );
      } catch (_) {}

      // Close sheet/dialog with null indicating failure
      try {
        if (sheetNav.canPop()) sheetNav.pop(null);
      } catch (_) {}
    }
  }

  /// Handle photo removal
  // ignore: use_build_context_synchronously
  static Future<void> _handlePhotoRemoval({
    required BuildContext sheetContext,
    required BuildContext parentContext,
    required TaskData task,
    String? organizationId,
    String? locationId,
    String? checklistId,
  }) async {
    // capture states to avoid BuildContext use across async gaps
    late final NavigatorState parentNav = Navigator.of(parentContext);
    late final NavigatorState sheetNav = Navigator.of(sheetContext);
    late final ScaffoldMessengerState messenger = ScaffoldMessenger.of(parentContext);

    try {
      // Ask for confirmation on the parent context while sheet/dialog remains open
      final confirmed = await showDialog<bool>(
        context: parentContext,
        builder:
            (c) => AlertDialog(
              title: const Text('Remove Photo'),
              content: const Text('Are you sure you want to remove this photo?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Remove'),
                ),
              ],
            ),
      );

      if (confirmed != true) return;

      // Show loading overlay
      _showLoadingOverlay(parentContext, 'Removing photo...');

      // Update task with empty photo URL
      await _checklistService.updateTaskPhotoInSubcollection(
        organizationId: organizationId ?? task.organizationId ?? '',
        locationId: locationId ?? task.locationId ?? '',
        checklistId: checklistId ?? task.checklistId ?? '',
        taskId: task.taskId,
        proofImageUrl: '',
      );

      // Close loading
      if (parentNav.canPop()) parentNav.pop();

      // Create updated task and show success
      final updatedTask = task.copyWith(photoUrl: '', proofImageUrl: '');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Photo removed successfully!'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );

      // Pop the sheet/dialog with updated task so callers receive it
      if (sheetNav.canPop()) sheetNav.pop(updatedTask);
    } catch (e) {
      try {
        if (parentNav.canPop()) parentNav.pop();
      } catch (_) {}

      final err = e.toString();
      String userMessage;
      if (err.contains('127.0.0.1') ||
          err.contains('Connection refused') ||
          err.contains('Failed host lookup') ||
          err.contains('ERR_CONNECTION_REFUSED')) {
        userMessage =
            'Unable to reach the Firebase Storage emulator at 127.0.0.1:9199.\nStart the emulator (e.g. `firebase emulators:start --only storage`) or switch to production Storage in your web config.';
      } else {
        userMessage = 'Error removing photo: $err';
      }

      try {
        messenger.showSnackBar(
          SnackBar(content: Text(userMessage), backgroundColor: Colors.red, duration: const Duration(seconds: 6)),
        );
      } catch (_) {}
      try {
        if (sheetNav.canPop()) sheetNav.pop(null);
      } catch (_) {}
    }
  }

  /// Show current photo in full screen
  /// Public wrapper to view existing photo without exposing private implementation
  static void viewExistingPhoto({required BuildContext context, required TaskData task}) {
    _showCurrentPhoto(context, task);
  }

  /// Show current photo in full screen (legacy private implementation)
  static void _showCurrentPhoto(BuildContext context, TaskData task) {
    final photoUrl = task.photoUrl?.isNotEmpty == true ? task.photoUrl : task.proofImageUrl;
    print('DEBUG: _showCurrentPhoto called with photoUrl: $photoUrl');

    if (photoUrl == null || photoUrl.isEmpty) return;

    // On web, our downloadUrl may be a signed URL which can still be blocked by CORS
    // if served indirectly. To be robust, fetch via callable proxyDownload which returns base64 bytes.
    if (kIsWeb && (photoUrl.contains('/o/') || photoUrl.contains('storage.googleapis.com'))) {
      print('DEBUG: Web detected, attempting proxy download for URL: $photoUrl');

      // Try to extract the storage path from the URL
      try {
        String storagePath;
        final uri = Uri.parse(photoUrl);

        // Handle new storage.googleapis.com format
        if (photoUrl.contains('storage.googleapis.com')) {
          // URL format: https://storage.googleapis.com/bucket-name/path/to/file.jpg?params...
          // Extract path from hostname/path without query params
          final pathWithoutQuery = uri.path;
          // Remove leading slash and extract everything after the bucket name
          final pathParts = pathWithoutQuery.split('/').where((part) => part.isNotEmpty).toList();
          if (pathParts.length > 1) {
            // Skip the bucket name (first part), take the rest as the storage path
            storagePath = pathParts.skip(1).join('/');
            print('DEBUG: Extracted storage path from googleapis URL: $storagePath');
          } else {
            print('DEBUG: Could not extract path from googleapis URL, pathParts: $pathParts');
            _showNetworkImage(dialogContext: context, photoUrl: photoUrl);
            return;
          }
        } else {
          // Handle old /o/ format
          final segments = uri.pathSegments;
          print('DEBUG: URL segments: $segments');

          final idx = segments.indexWhere((s) => s == 'o');
          if (idx >= 0 && idx + 1 < segments.length) {
            storagePath = Uri.decodeComponent(segments.sublist(idx + 1).join('/'));
            print('DEBUG: Extracted storage path from /o/ URL: $storagePath');
          } else {
            print('DEBUG: No /o/ pattern found, falling back to network image');
            _showNetworkImage(dialogContext: context, photoUrl: photoUrl);
            return;
          }
        }

        // Call the callable to get base64 bytes
        final functions = FirebaseFunctions.instance;
        final callable = functions.httpsCallable('proxyDownload');
        print('DEBUG: Calling proxyDownload function with path: $storagePath');

        callable
            .call(<String, dynamic>{'path': storagePath})
            .then((result) {
              print('DEBUG: proxyDownload success, result: ${result.data}');
              final data = result.data as Map<String, dynamic>;
              final base64 = data['base64'] as String?;
              if (base64 == null) {
                print('DEBUG: No base64 data received, falling back to network image');
                _showNetworkImage(dialogContext: context, photoUrl: photoUrl);
                return;
              }
              final bytes = base64Decode(base64);
              print('DEBUG: Successfully decoded base64, showing image dialog');
              showDialog(
                context: context,
                barrierColor: Colors.black87,
                builder:
                    (dialogContext) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(20),
                      child: Stack(
                        children: [
                          Center(child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain))),
                          Positioned(
                            top: 40,
                            right: 20,
                            child: IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(Icons.close, color: Colors.white, size: 30),
                              style: IconButton.styleFrom(backgroundColor: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ),
              );
            })
            .catchError((e) {
              print('DEBUG: proxyDownload failed: $e');
              // Fallback to network image on error
              _showNetworkImage(dialogContext: context, photoUrl: photoUrl);
            });
        return;
      } catch (e) {
        print('DEBUG: Exception during proxy download setup: $e');
        _showNetworkImage(dialogContext: context, photoUrl: photoUrl);
        return;
      }
    }

    print('DEBUG: Not web or no /o/ in URL, using network image directly');
    // Non-web or fallback: display via network
    _showNetworkImage(dialogContext: context, photoUrl: photoUrl);
  }

  static void _showNetworkImage({required BuildContext dialogContext, required String photoUrl}) {
    showDialog(
      context: dialogContext,
      barrierColor: Colors.black87,
      builder:
          (dc) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    child: Image.network(
                      photoUrl,
                      fit: BoxFit.contain,
                      errorBuilder:
                          (context, error, stackTrace) => Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error, color: Colors.red, size: 48),
                                const SizedBox(height: 16),
                                const Text('Failed to load photo'),
                                const SizedBox(height: 8),
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                              ],
                            ),
                          ),
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    onPressed: () => Navigator.pop(dc),
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  /// Public wrapper to show the current photo. Use this from other widgets.
  static void showCurrentPhoto(BuildContext context, TaskData task) {
    _showCurrentPhoto(context, task);
  }

  /// Show loading overlay
  static void _showLoadingOverlay(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (c) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(message)],
            ),
          ),
    );
  }
}
