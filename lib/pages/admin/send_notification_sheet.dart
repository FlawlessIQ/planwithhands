import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/state/notification_controller.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/shared/components/hands_buttons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/widgets/hands_text_field.dart';

class SendNotificationSheet extends ConsumerStatefulWidget {
  const SendNotificationSheet({super.key});

  @override
  ConsumerState<SendNotificationSheet> createState() => _SendNotificationSheetState();
}

class _SendNotificationSheetState extends ConsumerState<SendNotificationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  String _recipientType = 'All Users';
  String? _selectedGroup;
  String? _selectedLocation;
  // bool _pushOnLogin = false; // Removed the state variable

  List<Map<String, String>> _groups = [];
  List<Map<String, String>> _locations = []; // Changed to store both ID and name

  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOptions();
    _updateTitle();
  }

  Future<void> _loadOptions() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not signed in');
      final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();
      final orgId = userDoc.data()?['organizationId'] as String?;
      if (orgId == null) throw Exception('Organization not found');

      final groupsSnap =
          await FirestoreEnforcer.instance.collection('organizations').doc(orgId).collection('groups').get();
      final locSnap =
          await FirestoreEnforcer.instance.collection('organizations').doc(orgId).collection('locations').get();

      final groups =
          groupsSnap.docs.map((d) => {'id': d.id, 'name': (d.data()['name'] as String?) ?? 'Unnamed Group'}).toList();
      final locations =
          locSnap.docs
              .map(
                (d) => {
                  'id': d.id,
                  'name': (d.data()['locationName'] as String?) ?? (d.data()['name'] as String?) ?? 'Unnamed Location',
                },
              )
              .where((l) => l['name']! != 'Unnamed Location' && l['name']!.isNotEmpty)
              .toList();

      debugPrint('SendNotificationSheet: Raw location docs:');
      for (final doc in locSnap.docs) {
        debugPrint('  ${doc.id}: ${doc.data()}');
      }
      debugPrint('SendNotificationSheet: Loaded ${groups.length} groups: $groups');
      debugPrint('SendNotificationSheet: Loaded ${locations.length} locations: $locations');

      setState(() {
        _groups = groups;
        _locations = locations;
      });
    } catch (e) {
      debugPrint('Error loading notification options: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _updateTitle() {
    String t;
    switch (_recipientType) {
      case 'Group':
        if (_selectedGroup != null) {
          final groupName =
              _groups.firstWhere(
                (g) => g['id'] == _selectedGroup,
                orElse: () => <String, String>{'name': _selectedGroup!},
              )['name'];
          t = "Message for '$groupName'";
        } else {
          t = 'Group Message';
        }
        break;
      case 'Location':
        t =
            _selectedLocation != null
                ? "Message for '${_getLocationNameById(_selectedLocation!)}'"
                : 'Location Message';
        break;
      default:
        t = 'General Announcement';
    }
    _titleController.text = t;
  }

  String _getLocationNameById(String locationId) {
    final location = _locations.firstWhere((l) => l['id'] == locationId, orElse: () => {'name': 'Unknown Location'});
    return location['name']!;
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final ctrl = ref.read(notificationControllerProvider);
    try {
      String? recipientId;
      String? groupId;
      switch (_recipientType) {
        case 'Group':
          groupId = _selectedGroup;
          recipientId = 'all';
          break;
        case 'Location':
          recipientId = _selectedLocation; // This is now the location ID
          break;
        default:
          recipientId = null;
      }
      await ctrl.sendNotification(
        recipientId: recipientId ?? 'all',
        title: _titleController.text.trim(),
        body: _messageController.text.trim(),
        groupId: groupId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = 'Failed to send: $e';
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HandsColors.cardPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(20)),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SEND NOTIFICATION',
                      style: GoogleFonts.comfortaa(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: HandsColors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: HandsColors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _InfoTip(text: 'Send an in-app + push message to Everyone, a Group, or a Location.'),

                // Recipient type selector
                DropdownButtonFormField<String>(
                  initialValue: _recipientType,
                  items: const [
                    DropdownMenuItem(value: 'All Users', child: Text('All Users')),
                    DropdownMenuItem(value: 'Group', child: Text('Send to Group')),
                    DropdownMenuItem(value: 'Location', child: Text('Send to Location')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Recipient Type',
                    labelStyle: GoogleFonts.comfortaa(color: HandsColors.white70, fontSize: 14),
                    filled: true,
                    fillColor: HandsColors.secondaryContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(color: HandsColors.white12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(color: HandsColors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(color: HandsColors.handsOrange, width: 2),
                    ),
                  ),
                  style: GoogleFonts.comfortaa(color: HandsColors.white, fontSize: 14),
                  dropdownColor: HandsColors.secondaryContainer,
                  onChanged: (v) {
                    setState(() {
                      _recipientType = v!;
                      _selectedGroup = null;
                      _selectedLocation = null;
                      _updateTitle();
                    });
                  },
                ),

                const SizedBox(height: 12),
                if (_loading)
                  const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(HandsColors.handsOrange),
                    ),
                  )
                else ...[
                  if (_recipientType == 'Group')
                    DropdownButtonFormField<String>(
                      initialValue: _selectedGroup,
                      decoration: InputDecoration(
                        labelText: 'Select Group',
                        labelStyle: GoogleFonts.comfortaa(color: HandsColors.white70, fontSize: 14),
                        filled: true,
                        fillColor: HandsColors.secondaryContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: HandsColors.white12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: HandsColors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: HandsColors.handsOrange, width: 2),
                        ),
                      ),
                      hint: Text(
                        'Choose a group',
                        style: GoogleFonts.comfortaa(color: HandsColors.white70, fontSize: 14),
                      ),
                      items:
                          _groups
                              .map(
                                (g) => DropdownMenuItem(
                                  value: g['id'],
                                  child: Text(
                                    g['name']!,
                                    style: GoogleFonts.comfortaa(color: HandsColors.white, fontSize: 14),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedGroup = v;
                          _updateTitle();
                        });
                      },
                      dropdownColor: HandsColors.secondaryContainer,
                      validator: (v) => _recipientType == 'Group' && (v == null) ? 'Please select a group' : null,
                    ),
                  if (_recipientType == 'Location')
                    DropdownButtonFormField<String>(
                      initialValue: _selectedLocation,
                      items:
                          _locations
                              .map(
                                (l) => DropdownMenuItem(
                                  value: l['id'],
                                  child: Text(
                                    l['name']!,
                                    style: GoogleFonts.comfortaa(color: HandsColors.white, fontSize: 14),
                                  ),
                                ),
                              )
                              .toList(),
                      decoration: InputDecoration(
                        labelText: 'Select Location',
                        labelStyle: GoogleFonts.comfortaa(color: HandsColors.white70, fontSize: 14),
                        filled: true,
                        fillColor: HandsColors.secondaryContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: HandsColors.white12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: HandsColors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: HandsColors.handsOrange, width: 2),
                        ),
                      ),
                      onChanged: (v) {
                        setState(() {
                          _selectedLocation = v;
                          _updateTitle();
                        });
                      },
                      dropdownColor: HandsColors.secondaryContainer,
                      validator:
                          (v) =>
                              _recipientType == 'Location' && (v == null || v.isEmpty)
                                  ? 'Please select a location'
                                  : null,
                    ),
                ],

                const SizedBox(height: 16),
                HandsTextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: GoogleFonts.comfortaa(color: HandsColors.white70, fontSize: 14),
                    filled: true,
                    fillColor: HandsColors.secondaryContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(color: HandsColors.white12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(color: HandsColors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(color: HandsColors.handsOrange, width: 2),
                    ),
                  ),
                  style: GoogleFonts.comfortaa(color: HandsColors.white, fontSize: 14),
                  validator: (v) => v == null || v.isEmpty ? 'Enter a title' : null,
                ),
                const SizedBox(height: 12),
                HandsTextFormField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    labelStyle: GoogleFonts.comfortaa(color: HandsColors.white70, fontSize: 14),
                    filled: true,
                    fillColor: HandsColors.secondaryContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(color: HandsColors.white12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(color: HandsColors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(color: HandsColors.handsOrange, width: 2),
                    ),
                  ),
                  style: GoogleFonts.comfortaa(color: HandsColors.white, fontSize: 14),
                  maxLines: 3,
                  validator: (v) => v == null || v.isEmpty ? 'Enter a message' : null,
                ),

                const SizedBox(height: 12),

                if (_error != null) ...[
                  Text(_error!, style: GoogleFonts.comfortaa(color: HandsColors.error, fontSize: 13)),
                  const SizedBox(height: 8),
                ],

                const SizedBox(height: 16),
                _sending
                    ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(HandsColors.handsOrange),
                      ),
                    )
                    : HandsPrimaryButton(text: 'Send Notification', onPressed: _send, width: double.infinity),
              ],
            ),
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
        color: scheme.surfaceContainerHighest.withOpacity(0.5),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _visible = false),
            icon: Icon(Icons.close, size: 16, color: scheme.onSurfaceVariant),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }
}
