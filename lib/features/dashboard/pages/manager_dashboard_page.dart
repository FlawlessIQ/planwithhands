import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/global_widgets/bottom_nav_bar.dart';
import 'package:hands_app/global_widgets/generic_app_bar_content.dart';
import 'package:intl/intl.dart';
import 'package:hands_app/services/daily_checklist_service.dart';

class ManagerDashboardPage extends StatefulWidget {
  final String organizationId;
  const ManagerDashboardPage({super.key, required this.organizationId});

  @override
  State<ManagerDashboardPage> createState() => _ManagerDashboardPageState();
}

class _ManagerDashboardPageState extends State<ManagerDashboardPage> {
  int userRole = 1;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  late final String _todayKey;

  // Location selection at the top level
  String? _selectedLocationId;
  String? _selectedLocationName;
  List<Map<String, dynamic>> _availableLocations = [];
  bool _isLoadingLocations = true;
  bool _showLocationSelector = false;

  // Audit filters (removed location filter)
  String _searchTerm = '';
  String _selectedShift = 'all';
  // Checklist template filter
  String _selectedChecklist = 'all';
  String _selectedCompletion = 'all'; // all, completed, incomplete
  DateTimeRange? _selectedDateRange;

  List<Map<String, String>> _shifts = [];
  List<Map<String, String>> _checklists = [];

  @override
  void initState() {
    super.initState();
    _todayKey = _dateFormat.format(DateTime.now());
    _fetchUserRole();
    _loadLocations();
    // Auto-generate daily checklists when manager dashboard loads
    _ensureDailyChecklistsExist();
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      final data = userDoc.data()!;
      setState(() {
        userRole = data['userRole'] ?? 1;
      });
    }
  }

  Future<void> _ensureDailyChecklistsExist() async {
    try {
      final service = DailyChecklistService();
      await service.ensureDailyChecklistsExist(widget.organizationId);
      debugPrint(
          'Daily checklist generation check completed for organization ${widget.organizationId}');
    } catch (e) {
      debugPrint('Error ensuring daily checklists exist: $e');
    }
  }

  Future<void> _loadLocations() async {
    setState(() {
      _isLoadingLocations = true;
    });

    try {
      final locationsSnap = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('locations')
          .get();

      final locations = locationsSnap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['locationName'] ?? 'Unnamed Location',
          'isPrimary': data['isPrimary'] ?? false,
        };
      }).toList();

      // Sort so primary location comes first
      locations.sort((a, b) {
        if (a['isPrimary'] == true && b['isPrimary'] != true) return -1;
        if (b['isPrimary'] == true && a['isPrimary'] != true) return 1;
        return (a['name'] as String).compareTo(b['name'] as String);
      });

      setState(() {
        _availableLocations = locations;
        _showLocationSelector =
            locations.length > 1; // Show selector if multiple locations

        // Auto-select primary location or first location if available
        if (locations.isNotEmpty) {
          final primaryLocation = locations.firstWhere(
            (loc) => loc['isPrimary'] == true,
            orElse: () => locations.first,
          );
          _selectedLocationId = primaryLocation['id'];
          _selectedLocationName = primaryLocation['name'];
        }
      });

      // Load filter options after location is selected
      if (_selectedLocationId != null) {
        await _loadFilterOptions();
      }
    } catch (e) {
      debugPrint('Error loading locations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load locations: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoadingLocations = false;
      });
    }
  }

  Future<void> _loadFilterOptions() async {
    // Load shifts for the selected location
    final shiftsSnap = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('shifts')
        .where('locationIds', arrayContains: _selectedLocationId)
        .get();

    // Load checklist templates
    final templatesSnap = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('checklist_templates')
        .get();

    setState(() {
      _shifts = shiftsSnap.docs
          .map((d) => {
                'id': d.id,
                'name': d.data()['shiftName']?.toString() ?? 'Unnamed Shift'
              })
          .toList();

      _checklists = templatesSnap.docs
          .map((d) => {
                'id': d.id,
                'name': d.data()['name']?.toString() ?? 'Unnamed Checklist'
              })
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocations) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Manager Dashboard'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        bottomNavigationBar: BottomNavBar(currentIndex: 1, userRole: userRole),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: GenericAppBarContent(appBarTitle: 'Manager Dashboard', userRole: userRole),
        automaticallyImplyLeading: false,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: 1, userRole: userRole),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location selector at the top (only show if multiple locations)
            if (_showLocationSelector) ...[
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              color: Theme.of(context).primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Location Selection',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedLocationId,
                        decoration: const InputDecoration(
                          labelText: 'Select Location',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business),
                        ),
                        items: _availableLocations
                            .map((location) => DropdownMenuItem<String>(
                                  value: location['id'] as String,
                                  child: Text(location['name']! as String),
                                ))
                            .toList(),
                        onChanged: (value) async {
                          setState(() {
                            _selectedLocationId = value;
                            _selectedLocationName =
                                _availableLocations.firstWhere(
                              (loc) => loc['id'] == value,
                              orElse: () => {'name': 'Unknown Location'},
                            )['name'];
                          });
                          if (value != null) {
                            await _loadFilterOptions();
                          }
                        },
                      ),
                      if (_selectedLocationName != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Viewing data for: $_selectedLocationName',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Today header
            _buildTodayHeader(),
            const SizedBox(height: 20),
            _buildCurrentShiftsProgress(),
            const SizedBox(height: 30),
            _buildHistoricShiftPerformance(),
            const SizedBox(height: 30),
            _buildAuditSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayHeader() {
    final today = DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(today);

    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withValues(alpha: 0.8)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.dashboard, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Manager Dashboard',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formattedDate,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
            ),
            if (_selectedLocationName != null) ...[
              const SizedBox(height: 4),
              Text(
                'Location: $_selectedLocationName',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
              ),
            ],
            const SizedBox(height: 16),
            // Live organization stats filtered by location
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('organizationId', isEqualTo: widget.organizationId)
                  .snapshots(),
              builder: (context, userSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: _selectedLocationId != null
                      ? FirebaseFirestore.instance
                          .collection('organizations')
                          .doc(widget.organizationId)
                          .collection('locations')
                          .doc(_selectedLocationId!)
                          .collection('daily_checklists')
                          .where('date', isEqualTo: _todayKey)
                          .snapshots()
                      : _getAllLocationChecklistsStream(),
                  builder: (context, checklistSnapshot) {
                    // Count all users in organization (not filtered by location for total count)
                    final allUsers =
                        userSnapshot.hasData ? userSnapshot.data!.docs : [];

                    // If location is selected, filter users for that location
                    final totalUsers = _selectedLocationId != null
                        ? allUsers.where((doc) {
                            final userData = doc.data() as Map<String, dynamic>;
                            final userLocationIds = List<String>.from(
                                userData['locationIds'] ?? []);
                            return userLocationIds
                                .contains(_selectedLocationId);
                          }).length
                        : allUsers.length;

                    // Count users who have been active today (either logged in or have checklists)
                    int activeToday = 0;
                    if (userSnapshot.hasData) {
                      final now = DateTime.now();
                      final todayStart = DateTime(now.year, now.month, now.day);

                      // Get users who have logged in today or have checklists today
                      final usersWithChecklists = checklistSnapshot.hasData
                          ? checklistSnapshot.data!.docs
                              .map((d) => (d.data()
                                  as Map<String, dynamic>)['userId'] as String?)
                              .where((id) => id != null)
                              .toSet()
                          : <String>{};

                      for (final userDoc in allUsers) {
                        final userData = userDoc.data() as Map<String, dynamic>;
                        final userId = userDoc.id;

                        // If location is selected, only count users for that location
                        if (_selectedLocationId != null) {
                          final userLocationIds =
                              List<String>.from(userData['locationIds'] ?? []);
                          if (!userLocationIds.contains(_selectedLocationId)) {
                            continue;
                          }
                        }

                        // Check if user has checklists today
                        if (usersWithChecklists.contains(userId)) {
                          activeToday++;
                          continue;
                        }

                        // Check if user has logged in today
                        final lastLogin = userData['lastLogin'];
                        if (lastLogin != null) {
                          DateTime? loginDate;
                          try {
                            if (lastLogin is Timestamp) {
                              loginDate = lastLogin.toDate();
                            } else if (lastLogin is String) {
                              loginDate = DateTime.parse(lastLogin);
                            }

                            if (loginDate != null &&
                                loginDate.isAfter(todayStart)) {
                              activeToday++;
                            }
                          } catch (e) {
                            debugPrint(
                                'Error parsing lastLogin for user $userId: $e');
                          }
                        }
                      }
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: _buildStatChip(
                            icon: Icons.people,
                            label: 'Total Staff',
                            value: totalUsers.toString(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatChip(
                            icon: Icons.person_outline,
                            label: 'Active Today',
                            value: activeToday.toString(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatChip(
                            icon: Icons.assignment_turned_in,
                            label: 'Checklists',
                            value: checklistSnapshot.hasData
                                ? checklistSnapshot.data!.docs.length.toString()
                                : '0',
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentShiftsProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.access_time, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Text(
              'Current Shift Progress',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: _selectedLocationId != null
              ? FirebaseFirestore.instance
                  .collection('organizations')
                  .doc(widget.organizationId)
                  .collection('shifts')
                  .where('locationIds', arrayContains: _selectedLocationId)
                  .snapshots()
              : FirebaseFirestore.instance
                  .collection('organizations')
                  .doc(widget.organizationId)
                  .collection('shifts')
                  .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final shifts = snapshot.data!.docs;
            if (shifts.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(_selectedLocationId != null
                      ? 'No shifts configured for this location'
                      : 'No shifts configured'),
                ),
              );
            }

            return Column(
              children: shifts
                  .map((shiftDoc) => _buildShiftProgressCard(shiftDoc))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildShiftProgressCard(QueryDocumentSnapshot shiftDoc) {
    final shiftData = shiftDoc.data() as Map<String, dynamic>;
    final shiftName = shiftData['shiftName'] ?? 'Unnamed Shift';
    final startTime = shiftData['startTime'] ?? '';
    final endTime = shiftData['endTime'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shiftName,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      if (startTime.isNotEmpty && endTime.isNotEmpty)
                        Text(
                          '$startTime - $endTime',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                    ],
                  ),
                ),
                _buildTimeRemaining(startTime, endTime),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _selectedLocationId != null
                  ? FirebaseFirestore.instance
                      .collection('organizations')
                      .doc(widget.organizationId)
                      .collection('locations')
                      .doc(_selectedLocationId!)
                      .collection('daily_checklists')
                      .where('date', isEqualTo: _todayKey)
                      .where('shiftId', isEqualTo: shiftDoc.id)
                      .snapshots()
                  : const Stream.empty(), // No location selected, no data
              builder: (context, checklistSnapshot) {
                if (!checklistSnapshot.hasData) {
                  return const LinearProgressIndicator(value: 0);
                }

                final checklists = checklistSnapshot.data!.docs;
                if (checklists.isEmpty) {
                  return Column(
                    children: [
                      const LinearProgressIndicator(value: 0),
                      const SizedBox(height: 8),
                      Text(
                        'No checklists for today - Staff need to select this shift',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  );
                }

                int totalCompleted = 0;
                int totalTasks = 0;

                for (final doc in checklists) {
                  final data = doc.data() as Map<String, dynamic>;

                  // Use completedItems/totalItems if available, otherwise calculate from tasks
                  if (data.containsKey('completedItems') &&
                      data.containsKey('totalItems')) {
                    totalCompleted += (data['completedItems'] ?? 0) as int;
                    totalTasks += (data['totalItems'] ?? 0) as int;
                  } else {
                    // Fallback: calculate from tasks array
                    final tasks =
                        List<Map<String, dynamic>>.from(data['tasks'] ?? []);
                    totalTasks += tasks.length;
                    totalCompleted +=
                        tasks.where((task) => task['completed'] == true).length;
                  }
                }

                final progress =
                    totalTasks > 0 ? totalCompleted / totalTasks : 0.0;

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Task Progress'),
                        Text(
                          '$totalCompleted/$totalTasks tasks (${(progress * 100).round()}%)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 1.0
                            ? Colors.green
                            : Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRemaining(String startTime, String endTime) {
    if (startTime.isEmpty || endTime.isEmpty) {
      return Chip(
        label: const Text('No schedule'),
        backgroundColor: Colors.grey[200],
      );
    }

    try {
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      final start = DateFormat('yyyy-MM-dd HH:mm').parse('$today $startTime');
      final end = DateFormat('yyyy-MM-dd HH:mm').parse('$today $endTime');

      if (now.isBefore(start)) {
        final timeToStart = start.difference(now);
        return Chip(
          label: Text('Starts in ${_formatDuration(timeToStart)}'),
          backgroundColor: Colors.blue[100],
        );
      } else if (now.isAfter(end)) {
        return Chip(
          label: const Text('Shift ended'),
          backgroundColor: Colors.grey[300],
        );
      } else {
        final timeRemaining = end.difference(now);
        return Chip(
          label: Text('${_formatDuration(timeRemaining)} left'),
          backgroundColor: Colors.green[100],
        );
      }
    } catch (e) {
      return Chip(
        label: const Text('Invalid time'),
        backgroundColor: Colors.red[100],
      );
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  Widget _buildHistoricShiftPerformance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Text(
              'Historic Shift Performance',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Swipe to explore performance insights',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>>(
          key: ValueKey(
              _selectedLocationId), // Force rebuild when location changes
          future: _calculateShiftPerformanceAnalytics(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[100],
                ),
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[50],
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics_outlined,
                          size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No historical data available yet',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              );
            }

            final analytics = snapshot.data!;
            final topPerformers =
                analytics['topPerformers'] as List<Map<String, dynamic>>;
            final poorPerformers =
                analytics['poorPerformers'] as List<Map<String, dynamic>>;
            final dayAnalysis =
                analytics['dayAnalysis'] as List<Map<String, dynamic>>;

            // Create list of cards to display
            List<Widget> performanceCards = [];

            // Top Performers Card
            if (topPerformers.isNotEmpty) {
              performanceCards
                  .add(_buildSwipeableTopPerformersCard(topPerformers));
            }

            // Poor Performers Card
            if (poorPerformers.isNotEmpty) {
              performanceCards
                  .add(_buildSwipeablePoorPerformersCard(poorPerformers));
            }

            // Day Analysis Cards (one for each problematic shift)
            for (final analysis in dayAnalysis) {
              performanceCards.add(_buildSwipeableDayAnalysisCard(analysis));
            }

            // If no issues found, show a positive summary card
            if (performanceCards.isEmpty) {
              performanceCards.add(_buildSwipeableNoIssuesCard());
            }

            return SizedBox(
              height: 220,
              child: PageView.builder(
                itemCount: performanceCards.length,
                padEnds: false,
                controller: PageController(viewportFraction: 0.9),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index < performanceCards.length - 1 ? 12.0 : 0,
                    ),
                    child: performanceCards[index],
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        // Page indicator dots
        FutureBuilder<Map<String, dynamic>>(
          key: ValueKey(
              '${_selectedLocationId}_dots'), // Force rebuild when location changes
          future: _calculateShiftPerformanceAnalytics(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }

            final analytics = snapshot.data!;
            final topPerformers =
                analytics['topPerformers'] as List<Map<String, dynamic>>;
            final poorPerformers =
                analytics['poorPerformers'] as List<Map<String, dynamic>>;
            final dayAnalysis =
                analytics['dayAnalysis'] as List<Map<String, dynamic>>;

            int cardCount = 0;
            if (topPerformers.isNotEmpty) cardCount++;
            if (poorPerformers.isNotEmpty) cardCount++;
            cardCount += dayAnalysis.length;
            if (cardCount == 0) cardCount = 1; // No issues card

            if (cardCount <= 1) return const SizedBox.shrink();

            return Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                    cardCount,
                    (index) => Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.3),
                          ),
                        )),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSwipeableTopPerformersCard(
      List<Map<String, dynamic>> topPerformers) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.star, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top Performers',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                      ),
                      Text(
                        'Best completion rates',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.green.shade700,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topPerformers.take(3).length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final shift = topPerformers[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade100),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shift['shiftName'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${shift['totalSessions']} sessions',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${(shift['avgCompletionRate'] * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeablePoorPerformersCard(
      List<Map<String, dynamic>> poorPerformers) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.orange.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      const Icon(Icons.warning, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Needs Improvement',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                      ),
                      Text(
                        'Focus areas for training',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.orange.shade700,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: poorPerformers.take(3).length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final shift = poorPerformers[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade100),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade600,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Icon(Icons.trending_down,
                                color: Colors.white, size: 18),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shift['shiftName'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${shift['totalSessions']} sessions',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade600,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${(shift['avgCompletionRate'] * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeableDayAnalysisCard(Map<String, dynamic> analysis) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade50, Colors.red.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.calendar_today,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weekly Pattern Issue',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade800,
                                  ),
                        ),
                        Text(
                          '${analysis['shiftName']}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.red.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${analysis['worstDay']}s are problematic',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Only ${(analysis['worstDayRate'] * 100).toStringAsFixed(0)}% completion rate on ${analysis['worstDay']}s',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Based on ${analysis['worstDaySessionCount']} sessions',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _showDayAnalysisDetails(analysis),
                icon: const Icon(Icons.analytics, size: 16),
                label: const Text('View Details'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  backgroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeableNoIssuesCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(Icons.thumb_up, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'All Systems Green!',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'No performance issues detected. All shifts are performing consistently across all days of the week.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.search, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Text(
              'Audit Checklists & Tasks',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildAuditFilters(),
        const SizedBox(height: 16),
        _buildAuditResults(),
      ],
    );
  }

  Widget _buildAuditFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search bar
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search tasks, checklists, or users',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  setState(() => _searchTerm = value.toLowerCase()),
            ),
            const SizedBox(height: 16),

            // Filter row 1
            Row(
              children: [
                // Shift filter or loading
                Expanded(
                  child: _shifts.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                          value: _selectedShift,
                          decoration: const InputDecoration(
                            labelText: 'Shift',
                            border: OutlineInputBorder(),
                          ),
                          style: const TextStyle(fontSize: 14),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('All Shifts',
                                  style: TextStyle(fontSize: 14)),
                            ),
                            ..._shifts.map((shift) => DropdownMenuItem(
                                  value: shift['id'],
                                  child: Text(shift['name']!,
                                      style: const TextStyle(fontSize: 14)),
                                )),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedShift = value!),
                        ),
                ),
                const SizedBox(width: 12),

                // Checklist filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedChecklist,
                    decoration: const InputDecoration(
                      labelText: 'Checklists',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 14),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All Checklists',
                            style: TextStyle(fontSize: 14)),
                      ),
                      ..._checklists.map((c) => DropdownMenuItem(
                            value: c['id'],
                            child: Text(c['name']!,
                                style: const TextStyle(fontSize: 14)),
                          )),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedChecklist = value!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filter row 2
            Row(
              children: [
                // Completion filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCompletion,
                    decoration: const InputDecoration(
                      labelText: 'Completion Status',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 14),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child:
                            Text('All Tasks', style: TextStyle(fontSize: 14)),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('Completed Only',
                            style: TextStyle(fontSize: 14)),
                      ),
                      DropdownMenuItem(
                        value: 'incomplete',
                        child: Text('Incomplete Only',
                            style: TextStyle(fontSize: 14)),
                      ),
                      DropdownMenuItem(
                        value: 'incomplete_with_reason',
                        child: Text('Incomplete (with Reason)',
                            style: TextStyle(fontSize: 14)),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedCompletion = value!),
                  ),
                ),
                const SizedBox(width: 12),

                // Date range filter
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(_selectedDateRange == null
                        ? 'Select Date Range'
                        : '${DateFormat('M/d').format(_selectedDateRange!.start)} - ${DateFormat('M/d').format(_selectedDateRange!.end)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Clear filters button
            if (_searchTerm.isNotEmpty ||
                _selectedShift != 'all' ||
                _selectedChecklist != 'all' ||
                _selectedCompletion != 'all' ||
                _selectedDateRange != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear All Filters'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }

  void _clearFilters() {
    setState(() {
      _searchTerm = '';
      _selectedShift = 'all';
      _selectedChecklist = 'all';
      _selectedCompletion = 'all';
      _selectedDateRange = null;
    });
  }

  Widget _buildAuditResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildAuditQuery(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint('Error in audit query: ${snapshot.error}');
          // Try a simpler query without ordering if the main query fails
          return StreamBuilder<QuerySnapshot>(
            stream: _buildSimpleAuditQuery(),
            builder: (context, fallbackSnapshot) {
              if (!fallbackSnapshot.hasData) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.red[400]),
                        const SizedBox(height: 8),
                        const Text('Error loading audit data'),
                        const SizedBox(height: 8),
                        Text(
                          'Error: ${snapshot.error}',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final checklists = fallbackSnapshot.data!.docs;
              final filteredResults = _filterAuditResults(checklists);

              if (filteredResults.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.search_off,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        const Text('No results found with current filters'),
                        const SizedBox(height: 4),
                        Text(
                          'Found ${checklists.length} checklists but no matching tasks',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Clear Filters'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  Text(
                    'Found ${filteredResults.length} tasks from ${checklists.length} checklists',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredResults.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final taskData = filteredResults[index];
                      return _buildAuditResultItem(taskData);
                    },
                  ),
                ],
              );
            },
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final checklists = snapshot.data!.docs;
        debugPrint('Audit query returned ${checklists.length} checklists');

        final filteredResults = _filterAuditResults(checklists);

        if (filteredResults.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  const Text('No results found with current filters'),
                  const SizedBox(height: 4),
                  Text(
                    'Found ${checklists.length} checklists but no matching tasks',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear Filters'),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            Text(
              'Found ${filteredResults.length} tasks from ${checklists.length} checklists',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredResults.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final taskData = filteredResults[index];
                return _buildAuditResultItem(taskData);
              },
            ),
          ],
        );
      },
    );
  }

  Stream<QuerySnapshot> _buildAuditQuery() {
    // For the new nested structure, audit queries across all locations are complex
    // For now, we'll implement a simplified approach that requires location selection
    if (_selectedLocationId == null) {
      return const Stream.empty();
    }

    final endDate = DateTime.now();
    final startDate =
        _selectedDateRange?.start ?? endDate.subtract(const Duration(days: 30));
    final endDateForQuery = _selectedDateRange?.end ?? endDate;

    final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endDateStr = DateFormat('yyyy-MM-dd').format(endDateForQuery);

    var query = FirebaseFirestore.instance
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('locations')
        .doc(_selectedLocationId!)
        .collection('daily_checklists')
        .where('date', isGreaterThanOrEqualTo: startDateStr)
        .where('date', isLessThanOrEqualTo: endDateStr)
        .limit(500);

    return query.snapshots();
  }

  // Enhanced simple query for fallback with in-memory filtering
  Stream<QuerySnapshot> _buildSimpleAuditQuery() {
    // For the new nested structure, require location selection
    if (_selectedLocationId == null) {
      return const Stream.empty();
    }

    // Use the simplest possible query - just get recent checklists by date
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 30));
    final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);

    var query = FirebaseFirestore.instance
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('locations')
        .doc(_selectedLocationId!)
        .collection('daily_checklists')
        .where('date', isGreaterThanOrEqualTo: startDateStr)
        .limit(200);

    return query.snapshots();
  }

  List<Map<String, dynamic>> _filterAuditResults(
      List<QueryDocumentSnapshot> checklists) {
    List<Map<String, dynamic>> allTasks = [];
    for (final doc in checklists) {
      final data = doc.data() as Map<String, dynamic>;
      final checklistName = data['templateName'] ??
          data['checklistName'] ??
          data['name'] ??
          'Unnamed Checklist';
      final startedByUserId = data['startedByUserId'] ?? data['userId'] ?? '';
      final date = data['date'] ?? '';
      final shiftId = data['shiftId'] ?? '';
      final locationId = data['locationId'] ?? '';
      final checklistTemplateId =
          data['checklistTemplateId'] ?? data['templateId'] ?? '';

      // Apply Firestore-level filters first (in memory)

      // Location filter
      if (_selectedLocationId != null && locationId != _selectedLocationId) {
        continue;
      }

      // Shift filter
      if (_selectedShift != 'all' && shiftId != _selectedShift) {
        debugPrint(
            'Filtering out checklist ${doc.id} - shift $shiftId does not match selected shift $_selectedShift');
        continue;
      }

      // Checklist template filter
      if (_selectedChecklist != 'all' &&
          checklistTemplateId != _selectedChecklist) {
        continue;
      }

      final shiftName = _shifts.firstWhere(
            (s) => s['id'] == shiftId,
            orElse: () => {'name': 'Unknown Shift'},
          )['name'] ??
          'Unknown Shift';

      // Get tasks from this checklist
      final tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? []);

      debugPrint(
          'Processing checklist ${doc.id} (shift: $shiftName): ${tasks.length} tasks found');

      for (int i = 0; i < tasks.length; i++) {
        final task = tasks[i];

        // Try multiple possible field names for task description/name
        final taskName = task['description'] ??
            task['title'] ??
            task['name'] ??
            task['taskName'] ??
            task['taskTitle'] ??
            'Unnamed Task';

        // Check multiple possible completion fields
        final completed = task['isCompleted'] == true ||
            task['completed'] == true ||
            task['status'] == 'completed' ||
            task['done'] == true;
        final reason = task['reason'] ?? task['incompleteReason'] ?? '';

        // Get completed by information with fallback logic
        final completedBy = task['completedByUserName'] ??
            task['completedBy'] ??
            task['userName'] ??
            task['completedByUserId'] ??
            '';

        // Get completion timestamp
        final completedAt = task['completedAt'] ?? task['timestamp'];

        // Handle different timestamp formats
        DateTime? completedDateTime;
        if (completedAt != null) {
          try {
            if (completedAt is Timestamp) {
              completedDateTime = completedAt.toDate();
            } else if (completedAt is String) {
              completedDateTime = DateTime.parse(completedAt);
            }
          } catch (e) {
            debugPrint('Error parsing completion timestamp: $e');
          }
        }

        // Use createdAt/updatedAt as fallback timestamp
        final fallbackTimestamp = data['createdAt'] ?? data['updatedAt'];
        DateTime? fallbackDateTime;
        if (fallbackTimestamp != null && completedDateTime == null) {
          try {
            if (fallbackTimestamp is Timestamp) {
              fallbackDateTime = fallbackTimestamp.toDate();
            } else if (fallbackTimestamp is String) {
              fallbackDateTime = DateTime.parse(fallbackTimestamp);
            }
          } catch (e) {
            debugPrint('Error parsing fallback timestamp: $e');
          }
        }

        final finalTimestamp = completedDateTime ?? fallbackDateTime;

        // Extract photo URL from task data
        final photoUrl = task['photoUrl'] ??
            task['proofImageUrl'] ??
            task['imageUrl'] ??
            task['photo'] ??
            task['image'];

        // Apply completion filter
        if (_selectedCompletion == 'completed' && !completed) continue;
        if (_selectedCompletion == 'incomplete' && completed) continue;
        if (_selectedCompletion == 'incomplete_with_reason' &&
            (completed || reason.toString().trim().isEmpty)) {
          continue;
        }

        // Apply search filter
        if (_searchTerm.isNotEmpty) {
          final searchMatch = taskName.toLowerCase().contains(_searchTerm) ||
              checklistName.toLowerCase().contains(_searchTerm) ||
              completedBy.toLowerCase().contains(_searchTerm) ||
              shiftName.toLowerCase().contains(_searchTerm);
          if (!searchMatch) continue;
        }

        // Create display name for user
        String displayUserName = completedBy;
        if (displayUserName.isEmpty) {
          if (startedByUserId.isNotEmpty) {
            displayUserName = 'User $startedByUserId';
          } else {
            displayUserName = 'Unknown User';
          }
        }

        allTasks.add({
          'taskName': taskName,
          'checklistName': checklistName,
          'userName': displayUserName,
          'userId': completedBy.isNotEmpty ? completedBy : startedByUserId,
          'shiftName': shiftName,
          'shiftId': shiftId,
          'completed': completed,
          'timestamp': finalTimestamp,
          'date': date,
          'taskIndex': i,
          'checklistId': doc.id,
          'locationId': locationId,
          'taskId': task['id'] ?? task['taskId'] ?? 'task_$i',
          'reason': reason,
          'photoUrl': photoUrl, // Add photo URL to task data
        });
      }
    }

    debugPrint('Total tasks after filtering: ${allTasks.length}');
    debugPrint('Selected shift: $_selectedShift');
    if (_selectedShift != 'all') {
      final shiftTasks =
          allTasks.where((task) => task['shiftId'] == _selectedShift).length;
      debugPrint('Tasks matching selected shift: $shiftTasks');
    }

    // Sort by timestamp (most recent first)
    allTasks.sort((a, b) {
      final aTime = a['timestamp'];
      final bTime = b['timestamp'];

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      if (aTime is DateTime && bTime is DateTime) {
        return bTime.compareTo(aTime);
      }

      return 0;
    });

    return allTasks;
  }

  Widget _buildAuditResultItem(Map<String, dynamic> data) {
    final userName = data['userName'] ?? 'Unknown User';
    final taskName = data['taskName'] ?? 'Unnamed Task';
    final checklistName = data['checklistName'] ?? 'Unnamed Checklist';
    final shiftName = data['shiftName'] ?? 'Unknown Shift';
    final completed = data['completed'] == true;
    final timestamp = data['timestamp']; // This is already a DateTime object
    final date = data['date'] ?? 'Unknown Date';
    final photoUrl = data['photoUrl'];
    final reason = data['reason'] ?? '';

    // Handle timestamp properly - it's already a DateTime object from _filterAuditResults
    String time = 'Unknown Time';
    String displayDate = date;

    if (timestamp != null && timestamp is DateTime) {
      time = DateFormat('HH:mm').format(timestamp);
      displayDate = DateFormat('MMM d').format(timestamp);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // User avatar or initials
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Task info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(taskName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('Checklist: $checklistName',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      Text('Shift: $shiftName',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      Text('By: $userName',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      Text('Date: $displayDate $time',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      // Show reason if task is incomplete and has a reason
                      if (!completed && reason.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            border: Border.all(color: Colors.orange.shade200),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline,
                                  size: 14, color: Colors.orange.shade700),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Reason: $reason',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Action buttons row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Completion status
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: completed
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        completed ? 'Completed' : 'Incomplete',
                        style: TextStyle(
                          color: completed ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    // Photo viewing button - only show if photo exists and task is completed
                    if (photoUrl != null &&
                        photoUrl.toString().isNotEmpty &&
                        completed)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.photo_camera,
                              color: Colors.blue.shade700),
                          tooltip: 'View Task Photo',
                          onPressed: () =>
                              _showTaskPhotoDialog(photoUrl, taskName),
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Add this new method to show photo in a dialog
  void _showTaskPhotoDialog(String photoUrl, String taskName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.photo_camera, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Task Photo: $taskName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Photo content
              Flexible(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 3.0,
                      child: Image.network(
                        photoUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return SizedBox(
                            height: 300,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('Loading photo...'),
                                ],
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return SizedBox(
                            height: 300,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline,
                                      size: 48, color: Colors.red[400]),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Error loading image',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Please check your internet connection',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _calculateShiftPerformanceAnalytics() async {
    try {
      debugPrint(
          'Starting shift performance analytics calculation for location: $_selectedLocationId');

      // Early return if no location selected
      if (_selectedLocationId == null) {
        debugPrint('No location selected, returning empty analytics');
        return {
          'topPerformers': <Map<String, dynamic>>[],
          'poorPerformers': <Map<String, dynamic>>[],
          'dayAnalysis': <Map<String, dynamic>>[],
        };
      }

      // Get data from the last 30 days using the new nested structure
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 30));

      List<QueryDocumentSnapshot> allChecklists = [];

      // Query specific location only (since we always have a location selected)
      var checklistsQuery = FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('locations')
          .doc(_selectedLocationId!)
          .collection('daily_checklists')
          .where('date',
              isGreaterThanOrEqualTo:
                  DateFormat('yyyy-MM-dd').format(startDate))
          .where('date',
              isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(endDate))
          .limit(500);

      final checklistsQueryResult = await checklistsQuery.get();
      allChecklists = checklistsQueryResult.docs;

      final checklists = allChecklists;

      debugPrint('Found ${checklists.length} checklists for analytics');
      debugPrint(
          'Available shifts: ${_shifts.length} (${_shifts.map((s) => s['name']).join(', ')})');

      if (checklists.isEmpty) {
        debugPrint('No checklists found for performance analytics');
        return {
          'topPerformers': <Map<String, dynamic>>[],
          'poorPerformers': <Map<String, dynamic>>[],
          'dayAnalysis': <Map<String, dynamic>>[],
        };
      }

      // Group data by shift
      Map<String, List<Map<String, dynamic>>> shiftData = {};
      Map<String, Map<String, List<double>>> dayOfWeekData =
          {}; // shiftId -> dayOfWeek -> completion rates

      for (final doc in checklists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final shiftId = data['shiftId'] as String?;
        final dateStr = data['date'] as String?;

        if (shiftId == null || dateStr == null) continue;

        // Calculate completion rate - handle multiple possible task completion fields
        final tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? []);
        final totalTasks = tasks.length;

        if (totalTasks == 0) continue; // Skip checklists with no tasks

        if (totalTasks == 0) continue; // Skip checklists with no tasks

        final completedTasks = tasks
            .where((t) =>
                t['completed'] == true ||
                t['isCompleted'] == true ||
                t['status'] == 'completed')
            .length;

        final completionRate = completedTasks / totalTasks;

        debugPrint(
            'Checklist ${doc.id}: $completedTasks/$totalTasks tasks completed (${(completionRate * 100).round()}%)');

        // Group by shift
        shiftData.putIfAbsent(shiftId, () => []);
        shiftData[shiftId]!.add({
          'date': dateStr,
          'completionRate': completionRate,
        });

        // Group by day of week
        try {
          final date = DateFormat('yyyy-MM-dd').parse(dateStr);
          final dayOfWeek = DateFormat('EEEE').format(date);

          dayOfWeekData.putIfAbsent(shiftId, () => {});
          dayOfWeekData[shiftId]!.putIfAbsent(dayOfWeek, () => []);
          dayOfWeekData[shiftId]![dayOfWeek]!.add(completionRate);
        } catch (e) {
          debugPrint('Error parsing date $dateStr: $e');
        }
      }

      debugPrint('Grouped data by ${shiftData.length} shifts');

      // Calculate average performance for each shift
      List<Map<String, dynamic>> shiftPerformances = [];
      for (final shiftId in shiftData.keys) {
        final performances = shiftData[shiftId]!;
        if (performances.isEmpty) continue;

        final avgCompletionRate = performances
                .map((p) => p['completionRate'] as double)
                .reduce((a, b) => a + b) /
            performances.length;

        final totalSessions = performances.length;
        final shiftName = _shifts.isNotEmpty
            ? _shifts.firstWhere(
                (s) => s['id'] == shiftId,
                orElse: () => {'name': 'Unknown Shift ($shiftId)'},
              )['name']
            : 'Unknown Shift ($shiftId)';

        debugPrint(
            'Shift $shiftName: ${(avgCompletionRate * 100).round()}% avg completion ($totalSessions sessions)');

        shiftPerformances.add({
          'shiftId': shiftId,
          'shiftName': shiftName,
          'avgCompletionRate': avgCompletionRate,
          'totalSessions': totalSessions,
          'performances': performances,
        });
      }

      // Sort by performance
      shiftPerformances.sort((a, b) => (b['avgCompletionRate'] as double)
          .compareTo(a['avgCompletionRate'] as double));

      // Get top and poor performers
      final topPerformers = shiftPerformances.take(3).toList();
      final poorPerformers =
          shiftPerformances.reversed.take(3).toList().reversed.toList();

      debugPrint(
          'Top performers: ${topPerformers.length}, Poor performers: ${poorPerformers.length}');

      // Calculate day-of-week analysis
      List<Map<String, dynamic>> dayAnalysis = [];
      for (final shiftId in dayOfWeekData.keys) {
        final shiftName = _shifts.isNotEmpty
            ? _shifts.firstWhere(
                (s) => s['id'] == shiftId,
                orElse: () => {'name': 'Unknown Shift ($shiftId)'},
              )['name']
            : 'Unknown Shift ($shiftId)';

        final dayData = dayOfWeekData[shiftId]!;
        List<Map<String, dynamic>> dayPerformances = [];

        for (final day in [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ]) {
          if (dayData.containsKey(day) && dayData[day]!.isNotEmpty) {
            final rates = dayData[day]!;
            final avgRate = rates.reduce((a, b) => a + b) / rates.length;
            dayPerformances.add({
              'day': day,
              'avgCompletionRate': avgRate,
              'sessionCount': rates.length,
            });
          }
        }

        // Find the worst performing day for this shift
        if (dayPerformances.isNotEmpty) {
          dayPerformances.sort((a, b) => (a['avgCompletionRate'] as double)
              .compareTo(b['avgCompletionRate'] as double));

          final worstDay = dayPerformances.first;
          if ((worstDay['avgCompletionRate'] as double) < 0.8) {
            // Less than 80%
            dayAnalysis.add({
              'shiftId': shiftId,
              'shiftName': shiftName,
              'worstDay': worstDay['day'],
              'worstDayRate': worstDay['avgCompletionRate'],
                           'worstDaySessionCount': worstDay['sessionCount'],
              'allDayPerformances': dayPerformances,
            });
          }
        }
      }

      debugPrint(
          'Analytics complete: ${topPerformers.length} top, ${poorPerformers.length} poor, ${dayAnalysis.length} day issues');

      return {
        'topPerformers': topPerformers,
        'poorPerformers': poorPerformers,
        'dayAnalysis': dayAnalysis,
      };
    } catch (e, stackTrace) {
      debugPrint('Error in _calculateShiftPerformanceAnalytics: $e');
      debugPrint('Stack trace: $stackTrace');
      return {
        'topPerformers': <Map<String, dynamic>>[],
        'poorPerformers': <Map<String, dynamic>>[],
        'dayAnalysis': <Map<String, dynamic>>[],
      };
    }
  }

  void _showDayAnalysisDetails(Map<String, dynamic> analysis) {
    final allDayPerformances =
        analysis['allDayPerformances'] as List<Map<String, dynamic>>;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${analysis['shiftName']} - Weekly Performance'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Performance by Day of Week',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              ...allDayPerformances.map((dayPerf) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(dayPerf['day']),
                        ),
                        Expanded(
                          flex: 3,
                          child: LinearProgressIndicator(
                            value: dayPerf['avgCompletionRate'],
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              dayPerf['avgCompletionRate'] < 0.8
                                  ? Colors.red
                                  : dayPerf['avgCompletionRate'] < 0.9
                                      ? Colors.orange
                                      : Colors.green,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(dayPerf['avgCompletionRate'] * 100).round()}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Helper method to get all checklists across all locations
  Stream<QuerySnapshot> _getAllLocationChecklistsStream() {
    // This is a complex operation since Firestore doesn't support querying across subcollections
    // For now, we'll return an empty stream and handle this differently
    // In a real implementation, you might want to restructure or use a different approach
    return const Stream.empty();
  }
}
