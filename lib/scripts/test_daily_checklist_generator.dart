import 'package:flutter/material.dart';
import 'package:hands_app/scripts/daily_checklist_generator.dart';

/// Test script to verify the daily checklist generator
/// This can be run manually to test the generation logic
class DailyChecklistGeneratorTest {
  
  /// Test the daily checklist generation for a specific organization
  static Future<void> testGenerationForOrganization() async {
    const organizationId = '5dQCGM4MTiJsqVoedI04'; // Default organization ID from the app
    
    debugPrint('[Test] Starting test generation for organization: $organizationId');
    
    try {
      final generator = DailyChecklistGenerator();
      
      // Test generation for today
      await generator.generateChecklistsForOrganization(
        organizationId: organizationId,
      );
      
      debugPrint('[Test] Generation completed successfully!');
      
    } catch (e, stack) {
      debugPrint('[Test] Error during generation: $e\n$stack');
    }
  }
  
  /// Test the generation for a specific shift
  static Future<void> testGenerationForSpecificShift({
    required String organizationId,
    required String shiftId,
  }) async {
    debugPrint('[Test] Starting test generation for specific shift: $shiftId');
    
    try {
      final generator = DailyChecklistGenerator();
      
      await generator.generateChecklistsForSpecificShift(
        organizationId: organizationId,
        shiftId: shiftId,
      );
      
      debugPrint('[Test] Specific shift generation completed successfully!');
      
    } catch (e, stack) {
      debugPrint('[Test] Error during specific shift generation: $e\n$stack');
    }
  }
  
  /// Test the full generation process (all organizations)
  static Future<void> testFullGeneration() async {
    debugPrint('[Test] Starting full generation test...');
    
    try {
      await runDailyChecklistGeneration();
      
      debugPrint('[Test] Full generation completed successfully!');
      
    } catch (e, stack) {
      debugPrint('[Test] Error during full generation: $e\n$stack');
    }
  }
}

/// Example usage function that can be called from anywhere in the app
/// for testing purposes
Future<void> runDailyChecklistGenerationTest() async {
  debugPrint('[Test] Starting Daily Checklist Generation Test');
  
  // Test 1: Generate for default organization
  await DailyChecklistGeneratorTest.testGenerationForOrganization();
  
  // Test 2: You can uncomment and modify this to test a specific shift
  // await DailyChecklistGeneratorTest.testGenerationForSpecificShift(
  //   organizationId: '5dQCGM4MTiJsqVoedI04',
  //   shiftId: 'your-shift-id-here',
  // );
  
  // Test 3: Full generation (all organizations)
  // await DailyChecklistGeneratorTest.testFullGeneration();
  
  debugPrint('[Test] Daily Checklist Generation Test completed');
}
