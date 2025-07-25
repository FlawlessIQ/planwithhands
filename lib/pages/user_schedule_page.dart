import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

class UserSchedulePage extends StatefulWidget {
  const UserSchedulePage({super.key});

  @override
  State<UserSchedulePage> createState() => _UserSchedulePageState();
}

class _UserSchedulePageState extends State<UserSchedulePage> {
  List<ShiftData> _publishedShifts = [];
  bool _loading = true;
  String? _error;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Not logged in.';
        _loading = false;
      });
      return;
    }
    _userId = user.uid;
    try {
      // Get all published shifts for the user's organization
      final orgId = await _getUserOrganizationId(_userId!);
      if (orgId == null) {
        setState(() {
          _error = 'No organization found.';
          _loading = false;
        });
        return;
      }
      final shiftsSnap =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(orgId)
              .collection('shifts')
              .where('published', isEqualTo: true)
              .get();
      final shifts =
          shiftsSnap.docs.map((doc) {
            return ShiftData.fromJson(doc.data()).copyWith(shiftId: doc.id);
          }).toList();
      setState(() {
        _publishedShifts = shifts;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading shifts: $e';
        _loading = false;
      });
    }
  }

  Future<String?> _getUserOrganizationId(String userId) async {
    final userDoc =
        await FirestoreEnforcer.instance.collection('users').doc(userId).get();
    if (!userDoc.exists) return null;
    final data = userDoc.data()!;
    return data['organizationId'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Schedule'), centerTitle: true),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text(_error!))
              : _publishedShifts.isEmpty
              ? const Center(child: Text('No published shifts found.'))
              : ListView.builder(
                itemCount: _publishedShifts.length,
                itemBuilder: (context, index) {
                  final shift = _publishedShifts[index];
                  final isAssigned = shift.assignedUserIds.contains(_userId);
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: Icon(
                        isAssigned ? Icons.check_circle : Icons.group,
                        color: isAssigned ? Colors.green : Colors.blue,
                      ),
                      title: Text(shift.shiftName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${shift.startTime} - ${shift.endTime}'),
                          if (shift.locationIds.isNotEmpty)
                            Text('Location: ${shift.locationIds.join(", ")}'),
                          const SizedBox(height: 4),
                          Text('Assigned: ${shift.assignedUserIds.length}'),
                          if (shift.assignedUserIds.isNotEmpty)
                            Text('Users: ${shift.assignedUserIds.join(", ")}'),
                        ],
                      ),
                      trailing:
                          isAssigned
                              ? const Text(
                                'Assigned',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                              : null,
                    ),
                  );
                },
              ),
    );
  }
}
