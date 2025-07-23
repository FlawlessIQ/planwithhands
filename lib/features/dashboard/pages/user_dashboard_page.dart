import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/models/daily_checklist.dart';
import 'package:hands_app/services/daily_checklist_service.dart';
import 'package:hands_app/global_widgets/bottom_nav_bar.dart';
import 'package:hands_app/global_widgets/generic_app_bar_content.dart';

// --- MAIN DASHBOARD PAGE ---

class UserDashboardPage extends HookConsumerWidget {
  const UserDashboardPage({super.key});

  static const String organizationId = '5dQCGM4MTiJsqVoedI04';
  static const String defaultLocationId = 'uWvZCOadBCowwIh86tfq';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = useState(true);
    final errorMessage = useState<String?>(null);
    final assignedShifts = useState<List<ShiftData>>([]);
    final selectedLocationIds = useState<List<String>>([]);
    final allChecklists = useState<List<List<DailyChecklist>>>([]);
    final hasLoadedOnce = useState(false);
    final userRole = useState<int>(0);

    final now = DateTime.now();
    final todayString = DateFormat('yyyy-MM-dd').format(now);
    final todayDayName = DateFormat('EEEE').format(now);

    Future<void> fetchUserRole() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        userRole.value = data['userRole'] ?? 0;
      }
    }

    useEffect(() {
      fetchUserRole();
      if (!hasLoadedOnce.value) {
        Future<void> loadDashboardData() async {
          isLoading.value = true;
          errorMessage.value = null;
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            errorMessage.value = "You must be logged in to view the dashboard.";
            isLoading.value = false;
            return;
          }
          try {
            // Find all assigned shifts for today
            List<ShiftData> foundShifts = await _getAllShiftsForToday(user.uid, todayDayName, todayString);
            debugPrint("[Dashboard][DEBUG] Found ${foundShifts.length} shifts before filtering");
            // Shifts are already filtered by published schedules, so no need for additional published filter
            foundShifts.sort((a, b) => a.startTime.compareTo(b.startTime));
            debugPrint("[Dashboard][DEBUG] Setting ${foundShifts.length} shifts to assignedShifts");
            assignedShifts.value = foundShifts;
            selectedLocationIds.value = foundShifts.map((shift) => shift.locationIds.isNotEmpty ? shift.locationIds.first : defaultLocationId).toList();
            // Load checklists for each shift
            List<List<DailyChecklist>> checklistGroups = [];
            for (int i = 0; i < foundShifts.length; i++) {
              final shift = foundShifts[i];
              final locationId = selectedLocationIds.value[i];
              final checklists = await _loadChecklistsForShiftSimple(shift, locationId, todayString);
              checklistGroups.add(checklists);
            }
            allChecklists.value = checklistGroups;
          } catch (e, stack) {
            debugPrint("[Dashboard] Error loading dashboard data: $e\n$stack");
            errorMessage.value = "An error occurred while loading your dashboard.";
          } finally {
            isLoading.value = false;
          }
        }
        loadDashboardData();
        hasLoadedOnce.value = true;
      }
      return null;
    }, []);

    // --- UI BUILD METHOD ---
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: GenericAppBarContent(appBarTitle: 'Hands Dashboard', userRole: userRole.value),
        automaticallyImplyLeading: false,
      ),
      body: isLoading.value
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (errorMessage.value != null)
                    _InfoCard(message: errorMessage.value!, color: Colors.red),
                  Expanded(
                    child: assignedShifts.value.isNotEmpty
                        ? ListView.builder(
                            itemCount: assignedShifts.value.length,
                            itemBuilder: (context, shiftIndex) {
                              final shift = assignedShifts.value[shiftIndex];
                              final locationId = selectedLocationIds.value[shiftIndex];
                              final checklists = allChecklists.value.length > shiftIndex ? allChecklists.value[shiftIndex] : [];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _ShiftStatusCard(
                                    title: "Your Assigned Shift",
                                    shiftName: shift.shiftName,
                                    timeRange: "${shift.startTime} - ${shift.endTime}",
                                    color: Colors.green,
                                    icon: Icons.work_outline,
                                    onClearShift: () => _leaveVolunteerShift(context, shift),
                                  ),
                                  if (checklists.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Text(
                                        "Today's Checklists",
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ...checklists.map((checklist) => _ChecklistCard(
                                        checklist: checklist,
                                        onTaskToggled: () async {
                                          // Refresh only this shift's checklists
                                          final refreshed = await _loadChecklistsForShiftSimple(shift, locationId, todayString);
                                          allChecklists.value[shiftIndex] = refreshed;
                                          allChecklists.value = List.from(allChecklists.value);
                                        },
                                      )),
                                ],
                              );
                            },
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.work_off_outlined, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  "You don't have a shift assigned for today.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Use the 'Help Out Another Shift' button below to join a shift.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  // Help Out Button (unchanged)
                  ElevatedButton.icon(
                    onPressed: () async {
                      debugPrint("[Dashboard] Help Out button pressed");
                      final result = await showModalBottomSheet<Map<String, dynamic>>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) {
                          debugPrint("[Dashboard] Building _HelpOutSheet");
                          return _HelpOutSheet(
                            organizationId: UserDashboardPage.organizationId,
                            todayDayName: todayDayName,
                          );
                        },
                      );

                      debugPrint("[Dashboard] Modal result: $result");
                      if (result != null) {
                        final shift = result['shift'] as ShiftData;
                        final locationId = result['locationId'] as String;

                        // Add the new shift to the list of assigned shifts
                        assignedShifts.value = [...assignedShifts.value, shift];
                        selectedLocationIds.value = [...selectedLocationIds.value, locationId];

                        // Load the checklists for this new shift and add them
                        final newChecklists = await _loadChecklistsForShiftSimple(shift, locationId, todayString);
                        allChecklists.value = [...allChecklists.value, newChecklists];
                      }
                    },
                    icon: const Icon(Icons.volunteer_activism),
                    label: const Text("Help Out Another Shift"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
      // Floating action button removed
      bottomNavigationBar: BottomNavBar(currentIndex: 0, userRole: userRole.value),
    );
  }
}

// Helper to get all shifts for today
Future<List<ShiftData>> _getAllShiftsForToday(String userId, String todayDayName, String todayString) async {
  debugPrint("[Dashboard][DEBUG] _getAllShiftsForToday called for userId=$userId, todayDayName=$todayDayName, todayString=$todayString");
  final currentUser = FirebaseAuth.instance.currentUser;
  debugPrint("[Dashboard][DEBUG] FirebaseAuth.currentUser: ${currentUser != null ? currentUser.uid : 'null'}");
  final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
  debugPrint("[Dashboard][DEBUG] userDoc.exists=${userDoc.exists}");
  if (!userDoc.exists) {
    debugPrint("[Dashboard][DEBUG] No user document found for userId=$userId");
    return [];
  }

  final userData = userDoc.data()!;
  debugPrint("[Dashboard][DEBUG] userData: $userData");
  final organizationId = userData['organizationId'] as String?;
  debugPrint("[Dashboard][DEBUG] organizationId=$organizationId");
  if (organizationId == null) {
    debugPrint("[Dashboard][DEBUG][ERROR] organizationId is null for userId=$userId. userData: $userData");
    return [];
  }

  final userRole = userData['userRole'] ?? 0;
  debugPrint("[Dashboard][DEBUG] userRole=$userRole");
  List<String> locationIds = [];

  if (userRole == 2) { // Admin
    debugPrint("[Dashboard][DEBUG] User is admin, fetching all locations for org $organizationId");
    final locationsSnapshot = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(organizationId)
        .collection('locations')
        .get();
    locationIds = locationsSnapshot.docs.map((doc) => doc.id).toList();
    debugPrint("[Dashboard][DEBUG] Admin locationIds: $locationIds");
  } else if (userRole == 1 && userData['locationIds'] != null) { // Manager
    locationIds = List<String>.from(userData['locationIds']);
    debugPrint("[Dashboard][DEBUG] Manager locationIds: $locationIds");
  } else if (userData['locationId'] != null) { // General User
    locationIds = [userData['locationId']];
    debugPrint("[Dashboard][DEBUG] General user locationIds: $locationIds");
  }

  if (locationIds.isEmpty) {
    debugPrint("[Dashboard][DEBUG][ERROR] locationIds is empty for userId=$userId. userData: $userData");
    return [];
  }

  // 1. Get all published schedule IDs for the user's locations for the relevant date
  final publishedScheduleIds = <String>{};
  debugPrint("[Dashboard][DEBUG] Querying published schedules for org=$organizationId, locationIds=$locationIds, date=$todayString");
  final schedulesSnapshot = await FirebaseFirestore.instance
      .collectionGroup('schedules')
      .where('organizationId', isEqualTo: organizationId)
      .where('locationId', whereIn: locationIds)
      .where('published', isEqualTo: true)
      .where('date', isEqualTo: todayString)
      .get();
  debugPrint("[Dashboard][DEBUG] schedulesSnapshot.docs.length=${schedulesSnapshot.docs.length}");

  for (final doc in schedulesSnapshot.docs) {
    publishedScheduleIds.add(doc.id);
    final docData = doc.data();
    debugPrint("[Dashboard][DEBUG] Published schedule doc.id=${doc.id}, doc.data=$docData");
    if (!docData.containsKey('organizationId')) {
      debugPrint("[Dashboard][DEBUG][ERROR] Published schedule doc.id=${doc.id} is missing organizationId field! docData: $docData");
    }
    if (!docData.containsKey('locationId')) {
      debugPrint("[Dashboard][DEBUG][ERROR] Published schedule doc.id=${doc.id} is missing locationId field! docData: $docData");
    }
    if (!docData.containsKey('date')) {
      debugPrint("[Dashboard][DEBUG][ERROR] Published schedule doc.id=${doc.id} is missing date field! docData: $docData");
    }
  }

  if (publishedScheduleIds.isEmpty) {
    debugPrint("[Dashboard][DEBUG][ERROR] No published schedules found for today. org=$organizationId, locationIds=$locationIds, date=$todayString");
    return []; // No published schedules, so no shifts to show
  }
  debugPrint("[Dashboard][DEBUG] Found published schedule IDs: $publishedScheduleIds");

  // 2. Get schedule entries for the user that are part of a published schedule
  debugPrint("[Dashboard][DEBUG] Querying entries for org=$organizationId, userId=$userId, date=$todayString");
  
  try {
    // For collection group queries, we can't filter by organizationId/date since entries don't have these fields
    // Instead, we'll query by assignedUserIds and filter the results
    final querySnapshot = await FirebaseFirestore.instance
        .collectionGroup('entries')
        .where('assignedUserIds', arrayContains: userId)
        .get();
    debugPrint("[Dashboard][DEBUG] entries querySnapshot.docs.length=${querySnapshot.docs.length}");

    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      debugPrint("[Dashboard][DEBUG] schedule_entry doc.id=${doc.id}, data=$data");
      if (!data.containsKey('organizationId')) {
        debugPrint("[Dashboard][DEBUG][ERROR] schedule_entry doc.id=${doc.id} is missing organizationId field! data: $data");
      }
      if (!data.containsKey('locationId')) {
        debugPrint("[Dashboard][DEBUG][ERROR] schedule_entry doc.id=${doc.id} is missing locationId field! data: $data");
      }
      if (!data.containsKey('date')) {
        debugPrint("[Dashboard][DEBUG][ERROR] schedule_entry doc.id=${doc.id} is missing date field! data: $data");
      }
      if (!data.containsKey('assignedUserIds')) {
        debugPrint("[Dashboard][DEBUG][ERROR] schedule_entry doc.id=${doc.id} is missing assignedUserIds field! data: $data");
      }
    }

    // Convert entries to shifts by fetching the actual shift documents
    final shifts = <ShiftData>[];
    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      final entryScheduleId = data['scheduleId'] as String?;
      final shiftId = data['shiftId'] as String?;
      
      debugPrint("[Dashboard][DEBUG] Processing entry doc.id=${doc.id}, scheduleId=$entryScheduleId, shiftId=$shiftId");
      
      if (entryScheduleId == null || shiftId == null) continue;
      
      // Check if this entry belongs to one of today's published schedules
      if (!publishedScheduleIds.contains(entryScheduleId)) {
        debugPrint("[Dashboard][DEBUG] Entry ${doc.id} not in published schedules, skipping");
        continue;
      }
      
      // Fetch the actual shift document
      try {
        final shiftDoc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(organizationId)
            .collection('shifts')
            .doc(shiftId)
            .get();
            
        if (shiftDoc.exists) {
          final shift = ShiftData.fromJson(shiftDoc.data()!).copyWith(shiftId: shiftDoc.id);
          shifts.add(shift);
          debugPrint("[Dashboard][DEBUG] Added shift from collection group: ${shift.shiftName}");
        }
      } catch (e) {
        debugPrint("[Dashboard][DEBUG] Error fetching shift $shiftId: $e");
      }
    }

    debugPrint("[Dashboard][DEBUG] Found ${shifts.length} published shifts for the user.");
    return shifts;
    
  } catch (e, stack) {
    debugPrint("[Dashboard][DEBUG][ERROR] Error in collectionGroup query: $e\n$stack");
    debugPrint("[Dashboard][DEBUG] Falling back to direct location queries...");
    
    // Fallback: Query each location directly instead of using collectionGroup
    List<ShiftData> allShifts = [];
    for (final locationId in locationIds) {
      final scheduleId = 'schedule_${todayString}_$locationId';
      if (publishedScheduleIds.contains(scheduleId)) {
        try {
          final entriesSnapshot = await FirebaseFirestore.instance
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .doc(locationId)
              .collection('schedules')
              .doc(scheduleId)
              .collection('entries')
              .where('assignedUserIds', arrayContains: userId)
              .get();
          
          debugPrint("[Dashboard][DEBUG] Found ${entriesSnapshot.docs.length} entries in location $locationId");
          
          for (final entryDoc in entriesSnapshot.docs) {
            final entryData = entryDoc.data();
            debugPrint("[Dashboard][DEBUG] Entry in $locationId: ${entryDoc.id}, data=$entryData");
            
            if (entryData.containsKey('shiftId')) {
              final shiftId = entryData['shiftId'] as String;
              final shiftDoc = await FirebaseFirestore.instance
                  .collection('organizations')
                  .doc(organizationId)
                  .collection('shifts')
                  .doc(shiftId)
                  .get();
              
              if (shiftDoc.exists) {
                final shift = ShiftData.fromJson(shiftDoc.data()!).copyWith(shiftId: shiftDoc.id);
                allShifts.add(shift);
                debugPrint("[Dashboard][DEBUG] Added shift: ${shift.shiftName}");
              }
            }
          }
        } catch (e) {
          debugPrint("[Dashboard][DEBUG] Error querying location $locationId: $e");
        }
      }
    }
    
    debugPrint("[Dashboard][DEBUG] Fallback found ${allShifts.length} shifts");
    return allShifts;
  }
}

// Helper to load checklists for a shift (returns list)
Future<List<DailyChecklist>> _loadChecklistsForShiftSimple(
    ShiftData shift,
    String locationId,
    String todayString,
  ) async {
    try {
      final checklistSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(UserDashboardPage.organizationId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .where('shiftId', isEqualTo: shift.shiftId)
          .where('date', isEqualTo: todayString)
          .get();
      final checklists = checklistSnapshot.docs
          .map((doc) => DailyChecklist.fromMap(doc.data(), doc.id))
          .toList();
      // Fallback logic
      if (checklists.isEmpty && shift.checklistTemplateIds.isNotEmpty) {
        final dailyChecklistService = DailyChecklistService();
        final generatedChecklists = await dailyChecklistService.generateDailyChecklists(
          organizationId: UserDashboardPage.organizationId,
          locationId: locationId,
          shiftId: shift.shiftId,
          shiftData: shift,
          date: todayString,
        );
        return generatedChecklists;
      }
      return checklists;
    } catch (e, stack) {
      debugPrint("[Dashboard] Error loading checklists: $e\n$stack");
      return [];
    }
  }

  // Helper method to show the help out sheet
  Future<void> _showHelpOutSheet(
    BuildContext context,
    ValueNotifier<List<DailyChecklist>> currentChecklists,
    String todayString,
    ValueNotifier<String> selectedLocationId,
    ValueNotifier<ShiftData?> helpingShift,
  ) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HelpOutSheet(
        organizationId: UserDashboardPage.organizationId,
        todayDayName: DateFormat('EEEE').format(DateTime.now()),
      ),
    );

    if (result != null) {
      final shift = result['shift'] as ShiftData;
      final locationId = result['locationId'] as String;
      
      debugPrint("[Dashboard] User chose to help with shift '${shift.shiftName}' at location '$locationId'");
      
      helpingShift.value = shift;
      selectedLocationId.value = locationId;
      currentChecklists.value = await _loadChecklistsForShiftSimple(
        shift,
        locationId,
        todayString,
      );
    }
  }

  // Method to leave a volunteer shift (removes user from volunteers array)
  Future<void> _leaveVolunteerShift(BuildContext context, ShiftData shift) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in to leave shifts")),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Volunteer Shift'),
        content: Text('Are you sure you want to leave the "${shift.shiftName}" volunteer shift? This will remove you from future assignments for this shift.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave Shift'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Remove user from volunteers array
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(UserDashboardPage.organizationId)
          .collection('shifts')
          .doc(shift.shiftId)
          .update({
        'volunteers': FieldValue.arrayRemove([user.uid]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully left volunteer shift! Please refresh the page.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error leaving volunteer shift: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error leaving shift. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper method to check shift templates (original system)
  Future<ShiftData?> _checkShiftTemplates(String userId, String todayDayName) async {
    try {
      debugPrint("[Dashboard][DEBUG] Checking shift templates for user $userId, todayDayName=$todayDayName");
      final assignedShiftsQuery = FirebaseFirestore.instance
          .collection('organizations')
          .doc(UserDashboardPage.organizationId)
          .collection('shifts')
          .where('assignedUserIds', arrayContains: userId);
      final volunteeredShiftsQuery = FirebaseFirestore.instance
          .collection('organizations')
          .doc(UserDashboardPage.organizationId)
          .collection('shifts')
          .where('volunteers', arrayContains: userId);

      final assignedShiftsSnapshot = await assignedShiftsQuery.get();
      debugPrint("[Dashboard][DEBUG] assignedShiftsSnapshot.docs.length=${assignedShiftsSnapshot.docs.length}");
      final volunteeredShiftsSnapshot = await volunteeredShiftsQuery.get();
      debugPrint("[Dashboard][DEBUG] volunteeredShiftsSnapshot.docs.length=${volunteeredShiftsSnapshot.docs.length}");

      for (final doc in assignedShiftsSnapshot.docs) {
        try {
          final data = doc.data();
          debugPrint("[Dashboard][DEBUG] assigned shift doc.id=${doc.id}, data=$data");
          if (!data.containsKey('assignedUserIds')) {
            debugPrint("[Dashboard][DEBUG][ERROR] assigned shift doc.id=${doc.id} missing assignedUserIds field!");
          }
          if (!data.containsKey('days')) {
            debugPrint("[Dashboard][DEBUG][ERROR] assigned shift doc.id=${doc.id} missing days field!");
          }
          final shift = ShiftData.fromJson(data).copyWith(shiftId: doc.id);
          final isToday = shift.repeatsDaily || shift.days.contains(todayDayName);
          if (isToday) {
            final assignedUserIds = List<String>.from(shift.assignedUserIds);
            if (assignedUserIds.contains(userId)) {
              debugPrint("[Dashboard][DEBUG] Found assigned shift in templates: ${shift.shiftName} (ID: ${shift.shiftId})");
              return shift;
            }
          }
        } catch (e, stack) {
          debugPrint("[Dashboard][DEBUG] Failed to parse assigned shift doc ${doc.id}: $e\n$stack");
        }
      }

      for (final doc in volunteeredShiftsSnapshot.docs) {
        try {
          final data = doc.data();
          debugPrint("[Dashboard][DEBUG] volunteered shift doc.id=${doc.id}, data=$data");
          if (!data.containsKey('volunteers')) {
            debugPrint("[Dashboard][DEBUG][ERROR] volunteered shift doc.id=${doc.id} missing volunteers field!");
          }
          if (!data.containsKey('days')) {
            debugPrint("[Dashboard][DEBUG][ERROR] volunteered shift doc.id=${doc.id} missing days field!");
          }
          final shift = ShiftData.fromJson(data).copyWith(shiftId: doc.id);
          final isToday = shift.repeatsDaily || shift.days.contains(todayDayName);
          if (isToday) {
            final volunteers = List<String>.from(shift.volunteers);
            if (volunteers.contains(userId)) {
              debugPrint("[Dashboard][DEBUG] Found volunteered shift in templates: ${shift.shiftName} (ID: ${shift.shiftId})");
              return shift;
            }
          }
        } catch (e, stack) {
          debugPrint("[Dashboard][DEBUG] Failed to parse volunteered shift doc ${doc.id}: $e\n$stack");
        }
      }

      debugPrint("[Dashboard][DEBUG] No shifts found in templates for user $userId");
      return null;
    } catch (e, stack) {
      debugPrint("[Dashboard][DEBUG] Error checking shift templates: $e\n$stack");
      return null;
    }
  }

  // Helper method to check schedule entries for today's date
  Future<ShiftData?> _checkScheduleEntries(String userId, String todayString) async {
    try {
      debugPrint("[Dashboard][DEBUG] Checking schedule entries for user $userId on $todayString");
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("[Dashboard][DEBUG][ERROR] No authenticated user found.");
        return null;
      }
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      debugPrint("[Dashboard][DEBUG] userDoc.exists=${userDoc.exists}");
      if (!userDoc.exists) {
        debugPrint("[Dashboard][DEBUG][ERROR] No user document found for userId=${user.uid}");
        return null;
      }
      final userData = userDoc.data()!;
      debugPrint("[Dashboard][DEBUG] userData: $userData");
      final userRole = userData['userRole'] ?? 0;
      List<String> locationsToCheck = [];
      if (userRole == 2) {
        final locationsSnapshot = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(UserDashboardPage.organizationId)
            .collection('locations')
            .get();
        locationsToCheck = locationsSnapshot.docs.map((doc) => doc.id).toList();
        debugPrint("[Dashboard][DEBUG] Admin locationsToCheck: $locationsToCheck");
      } else if (userRole == 1 && userData['locationIds'] != null) {
        locationsToCheck = List<String>.from(userData['locationIds']);
        debugPrint("[Dashboard][DEBUG] Manager locationsToCheck: $locationsToCheck");
      } else if (userData['locationId'] != null) {
        locationsToCheck = [userData['locationId']];
        debugPrint("[Dashboard][DEBUG] General user locationsToCheck: $locationsToCheck");
      }
      debugPrint("[Dashboard][DEBUG] Checking ${locationsToCheck.length} locations for schedule entries");
      for (final locationId in locationsToCheck) {
        final scheduleId = 'schedule_${todayString}_$locationId';
        debugPrint("[Dashboard][DEBUG] Checking scheduleId=$scheduleId for locationId=$locationId");
        try {
          final entriesSnapshot = await FirebaseFirestore.instance
              .collection('organizations')
              .doc(UserDashboardPage.organizationId)
              .collection('locations')
              .doc(locationId)
              .collection('schedules')
              .doc(scheduleId)
              .collection('entries')
              .where('assignedUserIds', arrayContains: userId)
              .get();
          debugPrint("[Dashboard][DEBUG] Found ${entriesSnapshot.docs.length} schedule entries for user in location $locationId");
          for (final entryDoc in entriesSnapshot.docs) {
            try {
              final entryData = entryDoc.data();
              debugPrint("[Dashboard][DEBUG] schedule entry doc.id=${entryDoc.id}, data=$entryData");
              if (!entryData.containsKey('shiftId')) {
                debugPrint("[Dashboard][DEBUG][ERROR] schedule entry doc.id=${entryDoc.id} missing shiftId field!");
              }
              if (!entryData.containsKey('assignedUserIds')) {
                debugPrint("[Dashboard][DEBUG][ERROR] schedule entry doc.id=${entryDoc.id} missing assignedUserIds field!");
              }
              final shiftId = entryData['shiftId'] as String?;
              if (shiftId != null) {
                final shiftDoc = await FirebaseFirestore.instance
                    .collection('organizations')
                    .doc(UserDashboardPage.organizationId)
                    .collection('shifts')
                    .doc(shiftId)
                    .get();
                debugPrint("[Dashboard][DEBUG] shiftDoc.exists=${shiftDoc.exists} for shiftId=$shiftId");
                if (shiftDoc.exists) {
                  final shift = ShiftData.fromJson(shiftDoc.data()!).copyWith(shiftId: shiftDoc.id);
                  debugPrint("[Dashboard][DEBUG] Found assigned shift in schedule entries: ${shift.shiftName} (ID: ${shift.shiftId}) at location $locationId");
                  return shift;
                } else {
                  debugPrint("[Dashboard][DEBUG][ERROR] shiftDoc not found for shiftId=$shiftId");
                }
              }
            } catch (e, stack) {
              debugPrint("[Dashboard][DEBUG] Error processing schedule entry ${entryDoc.id}: $e\n$stack");
            }
          }
        } catch (e, stack) {
          debugPrint("[Dashboard][DEBUG] Error checking location $locationId: $e\n$stack");
        }
      }
      debugPrint("[Dashboard][DEBUG] No shifts found in schedule entries for user $userId");
      return null;
    } catch (e, stack) {
      debugPrint("[Dashboard][DEBUG] Error checking schedule entries: $e\n$stack");
      return null;
    }
  }

// --- UI WIDGETS ---

class _ShiftStatusCard extends StatelessWidget {
  final String title;
  final String shiftName;
  final String timeRange;
  final Color color;
  final IconData icon;
  final VoidCallback? onClearShift;

  const _ShiftStatusCard({
    required this.title,
    required this.shiftName,
    required this.timeRange,
    required this.color,
    required this.icon,
    this.onClearShift,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.1),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shiftName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeRange,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (onClearShift != null)
              IconButton(
                icon: const Icon(Icons.close),
                color: Colors.grey[600],
                onPressed: onClearShift,
              ),
          ],
        ),
      ),
    );
  }
}

class _NoShiftCard extends StatelessWidget {
  const _NoShiftCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.withOpacity(0.1),
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange[700], size: 32),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "No Shift Assigned",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "You can help out another shift today",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String message;
  final Color color;

  const _InfoCard({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.1),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(
          message,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}

class _ChecklistCard extends HookWidget {
  final DailyChecklist checklist;
  final VoidCallback? onTaskToggled;

  const _ChecklistCard({
    required this.checklist,
    this.onTaskToggled,
  });

  @override
  Widget build(BuildContext context) {
    final isExpanded = useState(false);
    final isCompleted = checklist.isCompleted;
    final completedTasksCount = checklist.tasks.where((task) => task.isCompleted).length;
    final totalTasks = checklist.tasks.length;
    final statusColor = isCompleted ? Colors.green : Colors.orange;
    final progressPercentage = totalTasks > 0 ? completedTasksCount / totalTasks : 0.0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            title: Text(
              checklist.templateName ?? 'Checklist',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$completedTasksCount of $totalTasks tasks completed"),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progressPercentage,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCompleted ? Icons.check_circle : Icons.pending_actions,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Icon(
                  isExpanded.value ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey[600],
                ),
              ],
            ),
            onTap: () => isExpanded.value = !isExpanded.value,
          ),
          if (isExpanded.value)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: checklist.tasks.map((task) => _TaskTile(
                  task: task,
                  checklist: checklist,
                  onTaskToggled: onTaskToggled ?? () {},
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskTile extends HookWidget {
  final DailyChecklistTask task;
  final DailyChecklist checklist;
  final VoidCallback onTaskToggled;

  const _TaskTile({
    required this.task,
    required this.checklist,
    required this.onTaskToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: task.isCompleted 
            ? Colors.green[50] 
            : task.notCompletedReason != null 
                ? Colors.orange[50] 
                : Colors.grey[50],
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: Checkbox(
              value: task.isCompleted,
              onChanged: (value) => _handleTaskToggle(context, value ?? false),
              activeColor: Colors.green,
            ),
            title: Text(
              task.description,
              style: TextStyle(
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                color: task.isCompleted ? Colors.grey[600] : Colors.black,
              ),
            ),
            subtitle: _buildSubtitle(),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Photo status indicator
                if (task.photoRequired)
                  IconButton(
                    icon: Icon(
                      Icons.camera_alt,
                      size: 20,
                      color: task.proofImageUrl != null 
                          ? Colors.green 
                          : Colors.orange,
                    ),
                    onPressed: () => _showPhotoDialog(context),
                  ),
                // Notes/reason indicator
                if (task.notes != null && task.notes!.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      Icons.note,
                      size: 20,
                      color: Colors.blue[600],
                    ),
                    onPressed: () => _showNotesDialog(context),
                  ),
                // Not completed reason indicator
                if (task.notCompletedReason != null && task.notCompletedReason!.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      Icons.warning,
                      size: 20,
                      color: Colors.orange[700],
                    ),
                    onPressed: () => _showNotCompletedReasonDialog(context),
                  ),
                // Actions menu
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                  onSelected: (value) => _handleMenuAction(context, value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'photo',
                      child: Row(
                        children: [
                          Icon(Icons.camera_alt, size: 18),
                          SizedBox(width: 8),
                          Text('Photo'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'notes',
                      child: Row(
                        children: [
                          Icon(Icons.note, size: 18),
                          SizedBox(width: 8),
                          Text('Notes'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'not_completed',
                      child: Row(
                        children: [
                          Icon(Icons.warning, size: 18),
                          SizedBox(width: 8),
                          Text('Cannot Complete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Status indicators row
          if (_hasStatusIndicators())
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: _buildStatusChips(),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _buildSubtitle() {
    if (task.isCompleted && task.completedBy != null) {
      return Text(
        "Completed by ${task.completedBy}",
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      );
    }
    return null;
  }

  bool _hasStatusIndicators() {
    return task.proofImageUrl != null ||
           (task.notCompletedReason != null && task.notCompletedReason!.isNotEmpty) ||
           (task.notes != null && task.notes!.isNotEmpty);
  }

  List<Widget> _buildStatusChips() {
    List<Widget> chips = [];
    
    if (task.proofImageUrl != null) {
      chips.add(
        Chip(
          label: const Text('Photo attached', style: TextStyle(fontSize: 10)),
          avatar: const Icon(Icons.camera_alt, size: 12),
          backgroundColor: Colors.green[100],
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
      chips.add(const SizedBox(width: 4));
    }
    
    if (task.notCompletedReason != null && task.notCompletedReason!.isNotEmpty) {
      chips.add(
        Chip(
          label: const Text('Cannot complete', style: TextStyle(fontSize: 10)),
          avatar: const Icon(Icons.warning, size: 12),
          backgroundColor: Colors.orange[100],
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
      chips.add(const SizedBox(width: 4));
    }
    
    if (task.notes != null && task.notes!.isNotEmpty) {
      chips.add(
        Chip(
          label: const Text('Notes added', style: TextStyle(fontSize: 10)),
          avatar: const Icon(Icons.note, size: 12),
          backgroundColor: Colors.blue[100],
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }
    
    return chips;
  }

  Future<void> _handleTaskToggle(BuildContext context, bool isCompleted) async {
    if (isCompleted && task.photoRequired && task.proofImageUrl == null) {
      // Photo is required but not uploaded
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Photo Required'),
          content: const Text('This task requires a photo to be completed. Would you like to add a photo now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add Photo'),
            ),
          ],
        ),
      );
      
      if (shouldContinue == true) {
        await _showPhotoDialog(context);
        return;
      } else {
        return; // Don't complete the task
      }
    }
    
    await _toggleTask(context, isCompleted);
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'photo':
        _showPhotoDialog(context);
        break;
      case 'notes':
        _showNotesDialog(context);
        break;
      case 'not_completed':
        _showNotCompletedReasonDialog(context);
        break;
    }
  }

  Future<void> _showPhotoDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => _PhotoDialog(
        task: task,
        checklist: checklist,
        onPhotoUpdated: onTaskToggled,
      ),
    );
  }

  Future<void> _showNotesDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => _NotesDialog(
        task: task,
        checklist: checklist,
        onNotesUpdated: onTaskToggled,
      ),
    );
  }

  Future<void> _showNotCompletedReasonDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => _NotCompletedReasonDialog(
        task: task,
        checklist: checklist,
        onReasonUpdated: onTaskToggled,
      ),
    );
  }

  Future<void> _toggleTask(BuildContext context, bool isCompleted) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You must be logged in to complete tasks")),
        );
        return;
      }

      // Update the task in Firestore
      final checklistRef = FirebaseFirestore.instance
          .collection('organizations')
          .doc(checklist.organizationId)
          .collection('locations')
          .doc(checklist.locationId)
          .collection('daily_checklists')
          .doc(checklist.id);

      // Find the task in the array and update it
      final updatedTasks = checklist.tasks.map((t) {
        if (t.taskId == task.taskId) {
          return t.copyWith(
            isCompleted: isCompleted,
            completedBy: isCompleted ? user.email ?? user.uid : null,
            completedAt: isCompleted ? DateTime.now() : null,
            // Clear not completed reason if task is now completed
            notCompletedReason: isCompleted ? null : t.notCompletedReason,
          );
        }
        return t;
      }).toList();

      // Check if all tasks are completed
      final allCompleted = updatedTasks.every((t) => t.isCompleted);

      // Update the document
      await checklistRef.update({
        'tasks': updatedTasks.map((t) => t.toMap()).toList(),
        'isCompleted': allCompleted,
        'updatedAt': FieldValue.serverTimestamp(),
        if (allCompleted) 'completedByUserId': user.uid,
        if (allCompleted) 'completedAt': FieldValue.serverTimestamp(),
      });

      onTaskToggled();

      // Show feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCompleted ? "Task completed!" : "Task unchecked",
          ),
          backgroundColor: isCompleted ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      debugPrint("Error updating task: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error updating task. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// --- TASK MANAGEMENT DIALOGS ---

class _PhotoDialog extends HookWidget {
  final DailyChecklistTask task;
  final DailyChecklist checklist;
  final VoidCallback onPhotoUpdated;

  const _PhotoDialog({
    required this.task,
    required this.checklist,
    required this.onPhotoUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final isUploading = useState(false);

    return AlertDialog(
      title: const Text('Task Photo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.proofImageUrl != null) ...[
              Image.network(
                task.proofImageUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: isUploading.value ? null : () => _replacePhoto(context, isUploading),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Replace'),
                  ),
                  OutlinedButton.icon(
                    onPressed: isUploading.value ? null : () => _removePhoto(context, isUploading),
                    icon: const Icon(Icons.delete),
                    label: const Text('Remove'),
                  ),
                ],
              ),
            ] else ...[
              const Icon(Icons.camera_alt, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                task.photoRequired 
                    ? 'This task requires a photo to be completed'
                    : 'Add a photo to document this task',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: isUploading.value ? null : () => _addPhoto(context, ImageSource.camera, isUploading),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                  ElevatedButton.icon(
                    onPressed: isUploading.value ? null : () => _addPhoto(context, ImageSource.gallery, isUploading),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ],
              ),
            ],
            if (isUploading.value) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Uploading photo...'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isUploading.value ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _addPhoto(BuildContext context, ImageSource source, ValueNotifier<bool> isUploading) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      
      if (pickedFile == null) return;
      
      isUploading.value = true;
      
      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('task_photos')
          .child(checklist.organizationId)
          .child(checklist.id)
          .child('${task.taskId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      await storageRef.putFile(File(pickedFile.path));
      final downloadUrl = await storageRef.getDownloadURL();
      
      // Update task in Firestore
      await _updateTaskPhoto(downloadUrl);
      
      onPhotoUpdated();
      
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error uploading photo. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> _replacePhoto(BuildContext context, ValueNotifier<bool> isUploading) async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace Photo'),
        content: const Text('How would you like to replace the photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Camera'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Gallery'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    
    if (source != null) {
      await _addPhoto(context, source, isUploading);
    }
  }

  Future<void> _removePhoto(BuildContext context, ValueNotifier<bool> isUploading) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Photo'),
        content: const Text('Are you sure you want to remove this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        isUploading.value = true;
        await _updateTaskPhoto(null);
        onPhotoUpdated();
        
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo removed'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error removing photo: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error removing photo. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        isUploading.value = false;
      }
    }
  }

  Future<void> _updateTaskPhoto(String? photoUrl) async {
    final checklistRef = FirebaseFirestore.instance
        .collection('organizations')
        .doc(checklist.organizationId)
        .collection('locations')
        .doc(checklist.locationId)
        .collection('daily_checklists')
        .doc(checklist.id);

    final updatedTasks = checklist.tasks.map((t) {
      if (t.taskId == task.taskId) {
        return t.copyWith(proofImageUrl: photoUrl);
      }
      return t;
    }).toList();

    await checklistRef.update({
      'tasks': updatedTasks.map((t) => t.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class _NotesDialog extends HookWidget {
  final DailyChecklistTask task;
  final DailyChecklist checklist;
  final VoidCallback onNotesUpdated;

  const _NotesDialog({
    required this.task,
    required this.checklist,
    required this.onNotesUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final notesController = useTextEditingController(text: task.notes ?? '');
    final isSaving = useState(false);

    return AlertDialog(
      title: const Text('Task Notes'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Add notes about this task...',
                border: OutlineInputBorder(),
              ),
            ),
            if (isSaving.value) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving.value ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isSaving.value ? null : () => _saveNotes(context, notesController.text, isSaving),
          child: const Text('Save'),
        ),
        if (task.notes != null && task.notes!.isNotEmpty)
          TextButton(
            onPressed: isSaving.value ? null : () => _deleteNotes(context, isSaving),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
      ],
    );
  }

  Future<void> _saveNotes(BuildContext context, String notes, ValueNotifier<bool> isSaving) async {
    try {
      isSaving.value = true;
      await _updateTaskNotes(notes.trim().isEmpty ? null : notes.trim());
      onNotesUpdated();
      
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notes saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving notes: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error saving notes. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _deleteNotes(BuildContext context, ValueNotifier<bool> isSaving) async {
    try {
      isSaving.value = true;
      await _updateTaskNotes(null);
      onNotesUpdated();
      
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notes deleted'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting notes: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error deleting notes. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _updateTaskNotes(String? notes) async {
    final checklistRef = FirebaseFirestore.instance
        .collection('organizations')
        .doc(checklist.organizationId)
        .collection('locations')
        .doc(checklist.locationId)
        .collection('daily_checklists')
        .doc(checklist.id);

    final updatedTasks = checklist.tasks.map((t) {
      if (t.taskId == task.taskId) {
        return t.copyWith(notes: notes);
      }
      return t;
    }).toList();

    await checklistRef.update({
      'tasks': updatedTasks.map((t) => t.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class _NotCompletedReasonDialog extends HookWidget {
  final DailyChecklistTask task;
  final DailyChecklist checklist;
  final VoidCallback onReasonUpdated;

  const _NotCompletedReasonDialog({
    required this.task,
    required this.checklist,
    required this.onReasonUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final reasonController = useTextEditingController(text: task.notCompletedReason ?? '');
    final isSaving = useState(false);

    return AlertDialog(
      title: const Text('Cannot Complete Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please explain why this task cannot be completed:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g., Equipment broken, supplies missing, etc.',
                border: OutlineInputBorder(),
              ),
            ),
            if (isSaving.value) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving.value ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isSaving.value ? null : () => _saveReason(context, reasonController.text, isSaving),
          child: const Text('Save'),
        ),
        if (task.notCompletedReason != null && task.notCompletedReason!.isNotEmpty)
          TextButton(
            onPressed: isSaving.value ? null : () => _deleteReason(context, isSaving),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
      ],
    );
  }

  Future<void> _saveReason(BuildContext context, String reason, ValueNotifier<bool> isSaving) async {
    if (reason.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    try {
      isSaving.value = true;
      await _updateTaskReason(reason.trim());
      onReasonUpdated();
      
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reason saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving reason: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error saving reason. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _deleteReason(BuildContext context, ValueNotifier<bool> isSaving) async {
    try {
      isSaving.value = true;
      await _updateTaskReason(null);
      onReasonUpdated();
      
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reason deleted'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting reason: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error deleting reason. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _updateTaskReason(String? reason) async {
    final checklistRef = FirebaseFirestore.instance
        .collection('organizations')
        .doc(checklist.organizationId)
        .collection('locations')
        .doc(checklist.locationId)
        .collection('daily_checklists')
        .doc(checklist.id);

    final updatedTasks = checklist.tasks.map((t) {
      if (t.taskId == task.taskId) {
        return t.copyWith(notCompletedReason: reason);
      }
      return t;
    }).toList();

    await checklistRef.update({
      'tasks': updatedTasks.map((t) => t.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

// --- HELP OUT BOTTOM SHEET ---

class _HelpOutSheet extends HookWidget {
  final String organizationId;
  final String todayDayName;

  const _HelpOutSheet({required this.organizationId, required this.todayDayName});

  @override
  Widget build(BuildContext context) {
    debugPrint("[Dashboard] _HelpOutSheet build method called");
    final selectedLocation = useState<Map<String, dynamic>?>(null);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    if (selectedLocation.value != null)
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => selectedLocation.value = null,
                      ),
                    Expanded(
                      child: Text(
                        selectedLocation.value == null ? "Select a Location" : "Select a Shift",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: selectedLocation.value == null
                    ? _LocationPicker(
                        organizationId: UserDashboardPage.organizationId,
                        onLocationSelected: (location) => selectedLocation.value = location,
                      )
                    : _ShiftPicker(
                        organizationId: UserDashboardPage.organizationId,
                        location: selectedLocation.value!,
                        todayDayName: todayDayName,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LocationPicker extends StatelessWidget {
  final String organizationId;
  final ValueChanged<Map<String, dynamic>> onLocationSelected;

  const _LocationPicker({required this.organizationId, required this.onLocationSelected});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('organizations')
          .doc(UserDashboardPage.organizationId)
          .collection('locations')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No locations found."));
        }

        return ListView(
          children: snapshot.data!.docs.map((doc) {
            final locationData = doc.data() as Map<String, dynamic>;
            return ListTile(
              title: Text(locationData['locationName'] ?? 'Unnamed Location'),
              onTap: () => onLocationSelected({'id': doc.id, ...locationData}),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ShiftPicker extends StatelessWidget {
  final String organizationId;
  final Map<String, dynamic> location;
  final String todayDayName;

  const _ShiftPicker({
    required this.organizationId,
    required this.location,
    required this.todayDayName,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('organizations')
          .doc(UserDashboardPage.organizationId)
          .collection('shifts')
          .where('locationIds', arrayContains: location['id'])
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading shifts."));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No shifts found for this location."));
        }

        final validShifts = snapshot.data!.docs.map((doc) {
          try {
            final shift = ShiftData.fromJson(doc.data()).copyWith(shiftId: doc.id);
            // Additional check for today
            if (shift.repeatsDaily || shift.days.contains(todayDayName)) {
              return shift;
            }
          } catch (e, stack) {
            debugPrint(
                "[Dashboard] _ShiftPicker: Failed to parse shift doc ${doc.id}: $e\n$stack");
          }
          return null; // Return null for invalid or non-today shifts
        }).whereType<ShiftData>().toList(); // Filter out all the nulls

        if (validShifts.isEmpty) {
          return const Center(
              child: Text("No shifts running today at this location."));
        }

        return ListView(
          children: validShifts.map((shift) {
            return ListTile(
              title: Text(shift.shiftName),
              subtitle: Text("${shift.startTime} - ${shift.endTime}"),
              onTap: () => Navigator.pop(context,
                  {'shift': shift, 'locationId': location['id']}),
            );
          }).toList(),
        );
      },
    );
  }
}

