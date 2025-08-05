import 'package:flutter/material.dart';

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
    // Don't show if only one location
    if (availableLocations.length <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            size: 18,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            'Location:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedLocationId,
                      isExpanded: true,
                      hint: const Text('Select location'),
                      style: Theme.of(context).textTheme.bodyMedium,
                      onChanged: (value) {
                        if (value != null) {
                          onLocationChanged(value);
                        }
                      },
                      items: availableLocations
                          .map((location) => DropdownMenuItem<String>(
                                value: location['id'] as String,
                                child: Text(
                                  location['name'] as String,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
