import 'package:flutter/material.dart';

/// A simple responsive AppBar title that scales the text down to fit available
/// width. Use this in AppBar(title: ...) so long titles shrink on small screens.
class ResponsiveAppBarTitle extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;

  const ResponsiveAppBarTitle(this.text, {Key? key, this.style, this.maxLines = 1}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? Theme.of(context).textTheme.titleLarge;

    // FittedBox with scaleDown will reduce the text size if it doesn't fit.
    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(text, style: baseStyle, maxLines: maxLines, overflow: TextOverflow.ellipsis),
          ),
        );
      },
    );
  }
}
