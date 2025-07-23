import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/state/user_state.dart';

class UploadDocumentBottomSheet extends HookConsumerWidget {
  final Map<String, dynamic>? documentData;
  final String? documentId;
  
  const UploadDocumentBottomSheet({
    super.key,
    this.documentData,
    this.documentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleController = useTextEditingController(
      text: documentData?['title'] ?? '',
    );
    final selectedCategory = useState<String?>(documentData?['category']);
    final selectedFile = useState<PlatformFile?>(null);
    final isUploading = useState(false);
    final formKey = useMemoized(() => GlobalKey<FormState>());
    
    final userState = ref.watch(userStateProvider);
    final theme = Theme.of(context);
    final isEditMode = documentData != null && documentId != null;

    final categories = [
      'Safety Procedures',
      'Cleaning Protocols',
      'Training Materials',
      'Operating Procedures',
      'Emergency Procedures',
      'Equipment Manuals',
      'Policy Documents',
      'Other'
    ];

    Future<void> pickFile() async {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'mp4', 'mov'],
          allowMultiple: false,
        );
        
        if (result != null && result.files.isNotEmpty) {
          selectedFile.value = result.files.first;
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error picking file: $e')),
          );
        }
      }
    }

    Future<void> uploadDocument() async {
      if (!formKey.currentState!.validate()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields')),
        );
        return;
      }

      // For editing, file is optional. For new documents, file is required.
      if (!isEditMode && selectedFile.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a file')),
        );
        return;
      }

      final orgId = userState.userData?.organizationId;
      if (orgId == null || orgId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organization ID is missing. Cannot upload document.')),
        );
        return;
      }

      isUploading.value = true;

      try {
        String? downloadUrl = documentData?['fileUrl']; // Keep existing URL if editing
        String? fileName = documentData?['fileName'];
        String fileType = documentData?['fileType'] ?? 'document';
        int? fileSize = documentData?['fileSize'];

        // Upload new file if selected
        if (selectedFile.value != null) {
          final file = selectedFile.value!;
          fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
          final storageRef = FirebaseStorage.instance.ref().child('documents/$fileName');
          
          UploadTask uploadTask;
          if (kIsWeb) {
            uploadTask = storageRef.putData(file.bytes!);
          } else {
            uploadTask = storageRef.putFile(File(file.path!));
          }

          final snapshot = await uploadTask;
          downloadUrl = await snapshot.ref.getDownloadURL();

          // Get file type
          final fileExtension = file.extension?.toLowerCase() ?? '';
          if (['jpg', 'jpeg', 'png'].contains(fileExtension)) {
            fileType = 'image';
          } else if (['mp4', 'mov'].contains(fileExtension)) {
            fileType = 'video';
          } else if (['pdf', 'doc', 'docx'].contains(fileExtension)) {
            fileType = 'document';
          }
          
          fileSize = file.size;
          fileName = file.name;
        }

        // Prepare document data
        final docData = {
          'title': titleController.text.trim(),
          'category': selectedCategory.value,
          'fileUrl': downloadUrl,
          'fileName': fileName,
          'fileType': fileType,
          'fileSize': fileSize,
          'organizationId': orgId,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (isEditMode) {
          // Update existing document - use the correct nested path
          await FirebaseFirestore.instance
              .collection('organizations')
              .doc(orgId)
              .collection('training_documents')
              .doc(documentId)
              .update(docData);
        } else {
          // Create new document - use the correct nested path
          docData['uploadedBy'] = userState.userData?.userId ?? 'unknown';
          docData['createdAt'] = FieldValue.serverTimestamp();
          await FirebaseFirestore.instance
              .collection('organizations')
              .doc(orgId)
              .collection('training_documents')
              .add(docData);
        }

        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEditMode ? 'Document updated successfully!' : 'Document uploaded successfully!')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e')),
          );
        }
      } finally {
        isUploading.value = false;
      }
    }

    String getFileIcon(String? extension) {
      switch (extension?.toLowerCase()) {
        case 'pdf':
          return '📄';
        case 'doc':
        case 'docx':
          return '📝';
        case 'jpg':
        case 'jpeg':
        case 'png':
          return '🖼️';
        case 'mp4':
        case 'mov':
          return '🎥';
        default:
          return '📁';
      }
    }

    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.canvasColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditMode ? 'Edit Document' : 'Upload Document',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Document Title
                      TextFormField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: 'Document Title',
                          hintText: 'Enter a descriptive title',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.title),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Please enter a document title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedCategory.value,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.category),
                        ),
                        items: categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) => selectedCategory.value = value,
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a category';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // File Picker Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditMode ? 'Change File (Optional)' : 'Select File',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Show existing file info for edit mode
                            if (isEditMode && selectedFile.value == null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      getFileIcon(documentData?['fileName']?.split('.').last),
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            documentData?['fileName'] ?? 'Unknown file',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (documentData?['fileSize'] != null)
                                            Text(
                                              '${(documentData!['fileSize'] / 1024 / 1024).toStringAsFixed(2)} MB',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: pickFile,
                                icon: const Icon(Icons.swap_horiz),
                                label: const Text('Change File'),
                              ),
                            ] else if (selectedFile.value == null) ...[
                              InkWell(
                                onTap: pickFile,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 32),
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: theme.primaryColor.withOpacity(0.3),
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.cloud_upload_outlined,
                                        size: 48,
                                        color: theme.primaryColor,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Tap to select file',
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          color: theme.primaryColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'PDF, DOC, Images, Videos',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ] else ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      getFileIcon(selectedFile.value!.extension),
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            selectedFile.value!.name,
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${(selectedFile.value!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.red),
                                      onPressed: () => selectedFile.value = null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: pickFile,
                                icon: const Icon(Icons.swap_horiz),
                                label: const Text('Change File'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isUploading.value ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: isUploading.value ? null : uploadDocument,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: isUploading.value
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              isEditMode ? 'Update Document' : 'Upload Document',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
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