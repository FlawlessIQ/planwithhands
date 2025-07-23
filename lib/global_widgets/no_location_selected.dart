import 'package:flutter/material.dart';

class NoLocationSelected extends StatelessWidget {
  const NoLocationSelected({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on,
            size: 60,
            color: Theme.of(context).colorScheme.primary,
          ),
          Text(
            'No Location Selected',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 48, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
