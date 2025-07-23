import 'package:flutter/material.dart';

class NewStateItemButton extends StatelessWidget {
  final Widget bottomSheet;
  final String buttonName;
  const NewStateItemButton({
    super.key,
    required this.bottomSheet,
    required this.buttonName,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        onPressed: () {
          showModalBottomSheet(
            backgroundColor: Theme.of(context).colorScheme.secondary,
            isScrollControlled: true,
            context: context,
            builder: (BuildContext context) {
              return bottomSheet;
            },
          );
        },
        style: ElevatedButton.styleFrom(
          elevation: 4,
          backgroundColor: Theme.of(context).colorScheme.primary,
          overlayColor: Theme.of(context).colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                buttonName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              SizedBox(height: 16),
              Icon(
                Icons.add,
                size: 48,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
