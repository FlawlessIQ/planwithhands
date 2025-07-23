import 'package:flutter/material.dart';

class ProgressCircle extends StatelessWidget {
  final double scale;
  const ProgressCircle({super.key, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Stack(
        children: [
          Container(
            width: 100 * scale,
            height: 100 * scale,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  bottom: 0,
                  child: AnimatedFractionallySizedBox(
                    duration: Duration(milliseconds: 250),
                    alignment: Alignment.bottomCenter,
                    widthFactor: 1,
                    heightFactor: 4 / 8,
                    child: Container(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16.0 * scale),
                      child: Text(
                        '50%',
                        style: TextStyle(fontSize: 20 * scale),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
