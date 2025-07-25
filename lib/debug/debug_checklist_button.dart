import 'package:flutter/material.dart';
import 'package:hands_app/debug/force_checklist_creator.dart';

class DebugChecklistButton extends StatelessWidget {
  final String organizationId;
  final String locationId;
  final String? shiftId;

  const DebugChecklistButton({
    super.key,
    required this.organizationId,
    required this.locationId,
    this.shiftId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: () => _forceCreateChecklists(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
        ),
        child: const Text(
          'EMERGENCY: Force Create Checklists',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _forceCreateChecklists(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Creating emergency checklists...')),
      );

      final today = DateTime.now();
      final dateString =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final forceCreator = ForceChecklistCreator();
      final checklists = await forceCreator.createEmergencyChecklists(
        organizationId,
        locationId,
        dateString,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'SUCCESS: Created ${checklists.length} emergency checklists!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Show detailed results
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Emergency Checklists Created'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Created ${checklists.length} checklists:'),
                  ...checklists.map(
                    (c) => Text('• ${c.templateName ?? "Checklist ${c.id}"}'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ERROR: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
