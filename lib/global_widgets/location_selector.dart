import 'package:flutter/material.dart';
import 'package:hands_app/services/location_selection_service.dart';

/// A compact, minimal location selector widget that can be reused across dashboard pages
class LocationSelector extends StatelessWidget {
  final String? selectedLocationId;
  final List<Map<String, dynamic>> availableLocations;
  final Function(String) onLocationChanged;
  final bool isLoading;

  const LocationSelector({
    super.key,
    required this.selectedLocationId,
    required this.availableLocations,
    required this.onLocationChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Determine current selection (fallback to global service if none provided)
    final effectiveSelectedId = selectedLocationId ?? LocationSelectionService.instance.currentLocationId;

    // Don't show if only one location
    if (availableLocations.length <= 1) {
      // Still update global so other pages remain consistent
      if (effectiveSelectedId == null && availableLocations.isNotEmpty) {
        LocationSelectionService.instance.setLocation(availableLocations.first['id'] as String?);
      }
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, size: 18, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text('Location:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Expanded(
            child:
                isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: effectiveSelectedId,
                        isExpanded: true,
                        hint: const Text('Select location'),
                        style: Theme.of(context).textTheme.bodyMedium,
                        onChanged: (value) {
                          if (value != null) {
                            // Update caller
                            onLocationChanged(value);
                            // Persist globally
                            LocationSelectionService.instance.setLocation(value);
                          }
                        },
                        items:
                            availableLocations
                                .map(
                                  (location) => DropdownMenuItem<String>(
                                    value: location['id'] as String,
                                    child: Text(location['name'] as String, overflow: TextOverflow.ellipsis),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
