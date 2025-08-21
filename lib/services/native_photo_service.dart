import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hands_app/services/daily_checklist_service.dart';
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
          (context) => AlertDialog(
            title: const Text('Add Photo'),
            content: const Text('Choose photo source:'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(
                onPressed:
                    () => _handlePhotoSelection(
                      context: context,
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
                        context: context,
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
          (context) => SafeArea(
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
                        context: context,
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
                        context: context,
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
                      Navigator.pop(context);
                      _showCurrentPhoto(context, task);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Remove Photo'),
                    subtitle: const Text('Delete the current photo'),
                    onTap:
                        () => _handlePhotoRemoval(
                          context: context,
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
                      onPressed: () => Navigator.pop(context),
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
  static Future<void> _handlePhotoSelection({
    required BuildContext context,
    required ImageSource source,
    required TaskData task,
    String? organizationId,
    String? locationId,
    String? checklistId,
  }) async {
    try {
      // Close the bottom sheet/dialog first
      Navigator.pop(context);

      // Show loading
      _showLoadingOverlay(context, 'Processing photo...');

      // Pick image
      final XFile? image = await _picker.pickImage(source: source, maxWidth: 1920, maxHeight: 1080, imageQuality: 85);

      if (image == null) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context); // Close loading
        }
        return;
      }

      // Upload via service
      final downloadUrl = await _checklistService.uploadTaskPhoto(
        organizationId: organizationId ?? task.organizationId ?? '',
        locationId: locationId ?? task.locationId ?? '',
        checklistId: checklistId ?? task.checklistId ?? '',
        taskId: task.taskId,
        imageFile: image,
      );

      // Close loading
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Create updated task
      final updatedTask = task.copyWith(photoUrl: downloadUrl, proofImageUrl: downloadUrl);

      // Show success and return updated task
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo uploaded successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Pop with updated task (this will be handled by caller)
        if (Navigator.canPop(context)) {
          Navigator.pop(context, updatedTask);
        }
      }
    } catch (e) {
      // Close loading if still showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading photo: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Handle photo removal
  static Future<void> _handlePhotoRemoval({
    required BuildContext context,
    required TaskData task,
    String? organizationId,
    String? locationId,
    String? checklistId,
  }) async {
    try {
      // Close the bottom sheet
      Navigator.pop(context);

      // Show confirmation
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Remove Photo'),
              content: const Text('Are you sure you want to remove this photo?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Remove'),
                ),
              ],
            ),
      );

      if (confirmed != true) return;

      // Show loading
      _showLoadingOverlay(context, 'Removing photo...');

      // Update task with empty photo URL
      await _checklistService.updateTaskPhotoInSubcollection(
        organizationId: organizationId ?? task.organizationId ?? '',
        locationId: locationId ?? task.locationId ?? '',
        checklistId: checklistId ?? task.checklistId ?? '',
        taskId: task.taskId,
        proofImageUrl: '',
      );

      // Close loading
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Create updated task
      final updatedTask = task.copyWith(photoUrl: '', proofImageUrl: '');

      // Show success
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo removed successfully!'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Return updated task
      if (Navigator.canPop(context)) {
        Navigator.pop(context, updatedTask);
      }
    } catch (e) {
      // Close loading if still showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing photo: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Show current photo in full screen
  static void _showCurrentPhoto(BuildContext context, TaskData task) {
    final photoUrl = task.photoUrl?.isNotEmpty == true ? task.photoUrl : task.proofImageUrl;
    if (photoUrl == null || photoUrl.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder:
          (context) => Dialog(
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
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  /// Show loading overlay
  static void _showLoadingOverlay(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(message)],
            ),
          ),
    );
  }
}
