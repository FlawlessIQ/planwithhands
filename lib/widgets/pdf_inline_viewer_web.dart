// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web; // for platformViewRegistry on web

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Web implementation: embeds an iframe pointing to the PDF URL.
class PdfInlineViewer extends StatefulWidget {
  final String url;

  const PdfInlineViewer({super.key, required this.url});

  @override
  State<PdfInlineViewer> createState() => _PdfInlineViewerState();
}

class _PdfInlineViewerState extends State<PdfInlineViewer> {
  late final String _viewType;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'pdf-iframe-${widget.url.hashCode}';
    _registerViewFactory();
  }

  void _registerViewFactory() {
    if (!kIsWeb || _registered) return;
    // Register a platform view factory for the iframe.
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe =
          html.IFrameElement()
            ..src = widget.url
            ..style.border = '0'
            ..style.width = '100%'
            ..style.height = '100%'
            ..allowFullscreen = true
            ..allow = 'fullscreen; clipboard-read; clipboard-write';
      return iframe;
    });
    _registered = true;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: HtmlElementView(viewType: _viewType)),
    );
  }
}
