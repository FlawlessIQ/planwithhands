import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:hands_app/state/user_state.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/widgets/hands_text_field.dart';
import 'package:hands_app/l10n/l10n.dart';

String localizedUploadDocumentCategoryLabel(
  BuildContext context,
  String category,
) {
  switch (category) {
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

class UploadDocumentBottomSheet extends HookConsumerWidget {
  final Map<String, dynamic>? documentData;
  final String? documentId;
  final String? locationId;
  final VoidCallback? onDocumentUploaded;

  const UploadDocumentBottomSheet({
    super.key,
    this.documentData,
    this.documentId,
    this.locationId,
    this.onDocumentUploaded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final titleController = useTextEditingController(
      text: documentData?['title'] ?? '',
    );
    final selectedCategory = useState<String?>(documentData?['category']);
    final selectedFile = useState<PlatformFile?>(null);
    final isUploading = useState(false);
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final organizationId = useState<String?>(null);
    final isLoadingOrgId = useState(true);

    final userState = ref.watch(userStateProvider);
    final isEditMode = documentData != null && documentId != null;

    useEffect(() {
      Future<void> loadOrganizationId() async {
        try {
          if (userState.userData?.organizationId != null) {
            organizationId.value = userState.userData!.organizationId;
            isLoadingOrgId.value = false;
            return;
          }

          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            final userDoc =
                await FirestoreEnforcer.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .get();
            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>;
              organizationId.value = userData['organizationId'] as String?;
            }
          }
        } finally {
          isLoadingOrgId.value = false;
        }
      }

      loadOrganizationId();
      return null;
    }, [userState.userData?.organizationId]);

    final categories = const [
      'Safety Procedures',
      'Cleaning Protocols',
      'Training Materials',
      'Operating Procedures',
      'Emergency Procedures',
      'Equipment Manuals',
      'Policy Documents',
      'Other',
    ];

    InputDecoration fieldDecoration({
      required String label,
      String? hint,
      Widget? prefixIcon,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        labelStyle: HandsModalTokens.labelStyle,
        hintStyle: GoogleFonts.inter(
          color: HandsModalTokens.textSubtle,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: HandsModalTokens.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HandsModalTokens.controlRadius),
          borderSide: const BorderSide(color: HandsModalTokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HandsModalTokens.controlRadius),
          borderSide: const BorderSide(color: HandsModalTokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HandsModalTokens.controlRadius),
          borderSide: const BorderSide(
            color: HandsModalTokens.accent,
            width: 1.2,
          ),
        ),
      );
    }

    Future<void> pickFile() async {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: [
            'pdf',
            'doc',
            'docx',
            'jpg',
            'jpeg',
            'png',
            'mp4',
            'mov',
          ],
          allowMultiple: false,
          withData: true,
        );
        if (result != null && result.files.isNotEmpty) {
          selectedFile.value = result.files.first;
        }
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.documentsPickFileError(e.toString()))),
        );
      }
    }

    Future<void> uploadDocument() async {
      if (isUploading.value) return;

      final currentState = formKey.currentState;
      if (currentState == null || !currentState.validate()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.documentsFillRequiredFields)),
        );
        return;
      }

      if (!isEditMode && selectedFile.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.documentsSelectFileRequired)),
        );
        return;
      }

      final orgId = organizationId.value;
      if (orgId == null || orgId.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.documentsMissingOrgId)));
        return;
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.documentsUserNotAuthenticated)),
        );
        return;
      }

      isUploading.value = true;
      try {
        String? downloadUrl = documentData?['fileUrl'];
        String? fileName = documentData?['fileName'];
        String fileType = documentData?['fileType'] ?? 'document';
        int? fileSize = documentData?['fileSize'];

        final file = selectedFile.value;
        if (file != null) {
          final fileBytes = file.bytes;
          if (fileBytes == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.documentsFileDataUnavailable)),
            );
            return;
          }

          final storedName =
              '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
          final storageRef = FirebaseStorage.instance.ref().child(
            'documents/$storedName',
          );

          final ext = file.extension?.toLowerCase() ?? '';
          final contentType = switch (ext) {
            'jpg' || 'jpeg' => 'image/jpeg',
            'png' => 'image/png',
            'pdf' => 'application/pdf',
            'doc' => 'application/msword',
            'docx' =>
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'mp4' => 'video/mp4',
            'mov' => 'video/quicktime',
            _ => 'application/octet-stream',
          };

          final metadata = SettableMetadata(contentType: contentType);
          final uploadTask = storageRef.putData(fileBytes, metadata);
          final snapshot = await uploadTask;
          downloadUrl = await snapshot.ref.getDownloadURL();

          if (['jpg', 'jpeg', 'png'].contains(ext)) {
            fileType = 'image';
          } else if (['mp4', 'mov'].contains(ext)) {
            fileType = 'video';
          } else {
            fileType = 'document';
          }

          fileSize = file.size;
          fileName = file.name;
        }

        final docPayload = <String, dynamic>{
          'title': titleController.text.trim(),
          'category': selectedCategory.value,
          'fileUrl': downloadUrl,
          'fileName': fileName,
          'fileType': fileType,
          'fileSize': fileSize,
          'organizationId': orgId,
          'locationId': locationId,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (isEditMode) {
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(orgId)
              .collection('training_documents')
              .doc(documentId)
              .update(docPayload);
        } else {
          docPayload['uploadedBy'] =
              userState.userData?.userId ??
              FirebaseAuth.instance.currentUser?.uid ??
              'unknown';
          docPayload['createdAt'] = FieldValue.serverTimestamp();
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(orgId)
              .collection('training_documents')
              .add(docPayload);
        }

        if (!context.mounted) return;
        onDocumentUploaded?.call();
        if (onDocumentUploaded == null) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditMode
                    ? l10n.documentsUpdatedSuccess
                    : l10n.documentsUploadedSuccess,
              ),
            ),
          );
        }
      } catch (e, stack) {
        debugPrint('Upload failed: $e');
        debugPrintStack(stackTrace: stack);

        String errorMessage = l10n.documentsUploadFailedPrefix;
        if (e.toString().contains('null check operator')) {
          errorMessage += l10n.documentsUploadFailedMissingData;
        } else if (e.toString().contains('permission')) {
          errorMessage += l10n.documentsUploadFailedPermission;
        } else if (e.toString().contains('storage')) {
          errorMessage += l10n.documentsUploadFailedStorage;
        } else {
          errorMessage += e.toString();
        }

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
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

    if (isLoadingOrgId.value) {
      return HandsBottomSheet(
        title: l10n.documentsUploadSheetTitle,
        subtitle: l10n.documentsUploadSheetLoadingSubtitle,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (organizationId.value == null) {
      return HandsBottomSheet(
        title: l10n.documentsUploadSheetTitle,
        subtitle: l10n.documentsUploadSheetMissingOrgSubtitle,
        child: Center(child: Text(l10n.documentsNoOrganization)),
      );
    }

    return HandsBottomSheet(
      title: isEditMode ? l10n.documentsEditTitle : l10n.documentsUploadTitle,
      subtitle: l10n.documentsUploadSubtitle,
      initialChildSize: 0.84,
      minChildSize: 0.46,
      maxChildSize: 0.96,
      actions: [
        HandsSecondaryButton(
          text: l10n.commonCancel,
          onPressed:
              isUploading.value ? null : () => Navigator.of(context).pop(),
        ),
        HandsPrimaryButton(
          text:
              isEditMode
                  ? l10n.documentsUpdateButton
                  : l10n.documentsUploadTitle,
          icon: isEditMode ? Icons.save_outlined : Icons.cloud_upload_outlined,
          isLoading: isUploading.value,
          onPressed: isUploading.value ? null : uploadDocument,
        ),
      ],
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoTip(text: l10n.documentsInfoTip),
              HandsModalSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.documentsDetails,
                      style: HandsModalTokens.sectionTitleStyle,
                    ),
                    const SizedBox(height: 12),
                    HandsTextFormField(
                      controller: titleController,
                      decoration: fieldDecoration(
                        label: l10n.documentsDocumentTitleLabel,
                        hint: l10n.documentsDocumentTitleHint,
                        prefixIcon: const Icon(
                          Icons.title_outlined,
                          size: 18,
                          color: HandsColors.white70,
                        ),
                      ),
                      style: GoogleFonts.inter(
                        color: HandsColors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true) {
                          return l10n.documentsDocumentTitleRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory.value,
                      decoration: fieldDecoration(
                        label: l10n.documentsCategoryLabel,
                        prefixIcon: const Icon(
                          Icons.category_outlined,
                          size: 18,
                          color: HandsColors.white70,
                        ),
                      ),
                      items:
                          categories
                              .map(
                                (category) => DropdownMenuItem(
                                  value: category,
                                  child: Text(
                                    localizedUploadDocumentCategoryLabel(
                                      context,
                                      category,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                      style: GoogleFonts.inter(
                        color: HandsColors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                      dropdownColor: HandsModalTokens.surfaceElevated,
                      onChanged: (value) => selectedCategory.value = value,
                      validator:
                          (value) =>
                              value == null
                                  ? l10n.documentsCategoryRequired
                                  : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              HandsModalSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditMode
                          ? l10n.documentsReplaceFileOptional
                          : l10n.documentsSelectFile,
                      style: HandsModalTokens.sectionTitleStyle,
                    ),
                    const SizedBox(height: 12),
                    if (isEditMode && selectedFile.value == null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              getFileIcon(
                                documentData?['fileName']?.split('.').last,
                              ),
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    documentData?['fileName'] ??
                                        l10n.documentsUnknownFile,
                                    style: GoogleFonts.inter(
                                      color: HandsColors.white,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (documentData?['fileSize'] != null)
                                    Text(
                                      '${(documentData!['fileSize'] / 1024 / 1024).toStringAsFixed(2)} MB',
                                      style: GoogleFonts.inter(
                                        color: HandsColors.white70,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
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
                        label: Text(l10n.documentsChangeFile),
                      ),
                    ] else if (selectedFile.value == null) ...[
                      InkWell(
                        onTap: pickFile,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          decoration: BoxDecoration(
                            color: HandsColors.handsOrange.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: HandsColors.handsOrange.withValues(
                                alpha: 0.28,
                              ),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.cloud_upload_outlined,
                                size: 42,
                                color: HandsColors.handsOrange,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                l10n.documentsTapToSelect,
                                style: GoogleFonts.inter(
                                  color: HandsColors.handsOrange,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.documentsSupportedFileTypes,
                                style: GoogleFonts.inter(
                                  color: HandsColors.white70,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
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
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3),
                          ),
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
                                    style: GoogleFonts.inter(
                                      color: HandsColors.white,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${(selectedFile.value!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                                    style: GoogleFonts.inter(
                                      color: HandsColors.white70,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => selectedFile.value = null,
                              icon: const Icon(Icons.close, color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: pickFile,
                        icon: const Icon(Icons.swap_horiz),
                        label: Text(l10n.documentsChangeFile),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTip extends StatefulWidget {
  final String text;

  const _InfoTip({required this.text});

  @override
  State<_InfoTip> createState() => _InfoTipState();
}

class _InfoTipState extends State<_InfoTip> {
  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _visible = false),
            icon: Icon(Icons.close, size: 16, color: scheme.onSurfaceVariant),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: context.l10n.documentsDismissTip,
          ),
        ],
      ),
    );
  }
}
