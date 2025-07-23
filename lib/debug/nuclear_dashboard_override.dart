import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hands_app/models/daily_checklist.dart';
import 'package:hands_app/debug/force_checklist_creator.dart';

class NuclearDashboardOverride extends HookConsumerWidget {
  final String organizationId;
  final String locationId;
  
  const NuclearDashboardOverride({
    super.key,
    required this.organizationId,
    required this.locationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚨 NUCLEAR DASHBOARD OVERRIDE'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              color: Colors.orange,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '⚠️ EMERGENCY MODE ACTIVATED\n\nThis screen bypasses all normal checklist generation and forces creation of working checklists.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: () => _createAndShowChecklists(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(20),
              ),
              child: const Text(
                '🚀 FORCE CREATE & SHOW CHECKLISTS',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: () => _resetEverything(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(20),
              ),
              child: const Text(
                '💀 NUCLEAR RESET - DELETE ALL & RECREATE',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            
            const SizedBox(height: 20),
            
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EMERGENCY PROCEDURES:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text('1. Force Create: Creates emergency checklists immediately'),
                    Text('2. Nuclear Reset: Deletes all checklists and recreates them'),
                    Text('3. Both bypass all normal validation and generation logic'),
                    Text('4. Use only when normal dashboard is completely broken'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAndShowChecklists(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🚀 FORCE CREATING EMERGENCY CHECKLISTS...')),
      );

      final today = DateTime.now();
      final dateString = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      final forceCreator = ForceChecklistCreator();
      final checklists = await forceCreator.createEmergencyChecklists(
        organizationId,
        locationId,
        dateString,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ SUCCESS: Created ${checklists.length} emergency checklists!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate to a simple checklist view
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _EmergencyChecklistView(checklists: checklists),
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ERROR: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resetEverything(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('💀 NUCLEAR OPTION'),
        content: const Text('This will DELETE ALL existing checklists and recreate them. Are you absolutely sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('YES, NUKE IT'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      // TODO: Implement nuclear reset functionality
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💀 NUCLEAR RESET NOT YET IMPLEMENTED'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}

class _EmergencyChecklistView extends StatelessWidget {
  final List<DailyChecklist> checklists;
  
  const _EmergencyChecklistView({required this.checklists});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚨 Emergency Checklists'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: checklists.length,
        itemBuilder: (context, index) {
          final checklist = checklists[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    checklist.templateName ?? 'Emergency Checklist ${index + 1}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Tasks: ${checklist.tasks.length}'),
                  Text('Completed: ${checklist.tasks.where((t) => t.isCompleted).length}'),
                  Text('ID: ${checklist.id}'),
                  const SizedBox(height: 8),
                  ...checklist.tasks.map((task) => Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text('• ${task.description}'),
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
