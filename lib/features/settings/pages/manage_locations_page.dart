import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hands_app/ui/location_bottom_sheet_new.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/widgets/responsive_appbar_title.dart';

class ManageLocationsPage extends StatefulWidget {
  final String organizationId;
  const ManageLocationsPage({super.key, required this.organizationId});

  @override
  State<ManageLocationsPage> createState() => _ManageLocationsPageState();
}

class _ManageLocationsPageState extends State<ManageLocationsPage> {
  Future<void> _deleteLocation(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final isPrimary = data['isPrimary'] as bool? ?? false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Location'),
            content: Text('Delete "${data['locationName'] ?? 'Location'}"? This cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      final orgRef = FirestoreEnforcer.instance.collection('organizations').doc(widget.organizationId);
      final locsRef = orgRef.collection('locations');
      final batch = FirestoreEnforcer.instance.batch();

      // Delete the location
      batch.delete(doc.reference);

      // Decrement count
      batch.update(orgRef, {'locationCount': FieldValue.increment(-1), 'updatedAt': FieldValue.serverTimestamp()});

      if (isPrimary) {
        // Set another location as primary if any exist
        final others = await locsRef.where(FieldPath.documentId, isNotEqualTo: doc.id).limit(1).get();
        if (others.docs.isNotEmpty) {
          batch.update(others.docs.first.reference, {'isPrimary': true, 'updatedAt': FieldValue.serverTimestamp()});
        }
      }

      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Location deleted'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // Build a displayable address string from various shapes we may have stored historically
  String _resolveAddressString(Map<String, dynamic> data) {
    // Prefer new structured fields
    final formatted = data['formattedAddress'];
    if (formatted is String && formatted.trim().isNotEmpty) return formatted.trim();

    final address = data['address'];
    if (address is String && address.trim().isNotEmpty) return address.trim();
    if (address is Map) {
      // Sometimes address was stored as a map with nested fields
      final street = address['street'] as String?;
      final city = address['city'] as String?;
      final state = address['state'] as String?;
      final zip = (address['zipCode'] as String?) ?? (address['zip'] as String?);
      final parts =
          [street, city, state, zip].whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (parts.isNotEmpty) return parts.join(', ');
    }

    // Legacy flat fields
    final street = data['street'] as String?;
    final city = data['city'] as String?;
    final state = data['state'] as String?;
    final zip = (data['zipCode'] as String?) ?? (data['zip'] as String?);
    final parts =
        [street, city, state, zip].whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(', ');

    return '';
  }

  Future<void> _setPrimary(DocumentSnapshot doc) async {
    try {
      final orgRef = FirestoreEnforcer.instance.collection('organizations').doc(widget.organizationId);
      final locsRef = orgRef.collection('locations');

      final batch = FirestoreEnforcer.instance.batch();
      final all = await locsRef.get();
      for (final d in all.docs) {
        batch.update(d.reference, {'isPrimary': d.id == doc.id, 'updatedAt': FieldValue.serverTimestamp()});
      }
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Primary location updated'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update primary: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgRef = FirestoreEnforcer.instance.collection('organizations').doc(widget.organizationId);
    final locsRef = orgRef.collection('locations').orderBy('createdAt', descending: false);

    return Scaffold(
      appBar: AppBar(title: const ResponsiveAppBarTitle('Manage Locations')),
      body: StreamBuilder<QuerySnapshot>(
        stream: locsRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No locations yet'),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final created = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(builder: (_) => LocationWizard(organizationId: widget.organizationId)),
                        );
                        if (created == true && mounted) setState(() {});
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Locations'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final d = docs[index];
              final data = d.data() as Map<String, dynamic>? ?? {};
              final name = (data['locationName'] as String?)?.trim();
              // Build a robust address string handling both new structured fields and legacy map shapes
              String address = _resolveAddressString(data);
              final isPrimary = data['isPrimary'] as bool? ?? false;

              return ListTile(
                leading: Icon(isPrimary ? Icons.star : Icons.place_outlined, color: isPrimary ? Colors.amber : null),
                title: Text(name?.isNotEmpty == true ? name! : '(No name)'),
                subtitle: Text(address.isNotEmpty ? address : '(No address)'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    switch (v) {
                      case 'primary':
                        await _setPrimary(d);
                        break;
                      case 'delete':
                        await _deleteLocation(d);
                        break;
                    }
                  },
                  itemBuilder:
                      (ctx) => [
                        if (!isPrimary)
                          const PopupMenuItem(
                            value: 'primary',
                            child: ListTile(leading: Icon(Icons.star), title: Text('Set as primary')),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete')),
                        ),
                      ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(
            context,
          ).push<bool>(MaterialPageRoute(builder: (_) => LocationWizard(organizationId: widget.organizationId)));
          if (created == true && mounted) setState(() {});
        },
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Add Locations'),
      ),
    );
  }
}
