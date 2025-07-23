import 'package:flutter/material.dart';

class CardTitleText extends StatelessWidget {
  final String text;
  final Color? textColor;
  const CardTitleText({super.key, required this.text, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
    );
  }
}
