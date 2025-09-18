// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web; // for platformViewRegistry on web

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _hasError = false;
  bool _iframeBlocked = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'pdf-iframe-${widget.url.hashCode}';
    _registerViewFactory();
    _checkIframeCompatibility();
  }

  void _checkIframeCompatibility() {
    // Check if this is a Firebase Storage URL which might have CSP restrictions
    if (widget.url.contains('firebasestorage.googleapis.com')) {
      print('[PdfInlineViewer] Firebase Storage URL detected - may have iframe restrictions');
      // Set a timer to check if iframe loads successfully
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && !_hasError) {
          // If no explicit error but also likely no content loaded, assume blocked
          setState(() {
            _iframeBlocked = true;
          });
        }
      });
    }
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
            // Use the HTML allow attribute (includes fullscreen) to avoid precedence warnings
            ..allow = 'fullscreen; clipboard-read; clipboard-write'
            // Try to handle CSP issues
            ..setAttribute('sandbox', 'allow-same-origin allow-scripts allow-popups allow-forms');

      // Add detailed debugging and error handling for iframe loading
      iframe.onLoad.listen((_) {
        print('[PdfInlineViewer] PDF iframe loaded successfully: ${widget.url}');
        if (mounted) {
          setState(() {
            _hasError = false;
            _iframeBlocked = false;
          });
        }
      });

      iframe.onError.listen((event) {
        print('[PdfInlineViewer] PDF iframe error: $event, URL: ${widget.url}');
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      });

      // Listen for security errors that might indicate CSP blocking
      html.window.addEventListener('message', (html.Event event) {
        final messageEvent = event as html.MessageEvent;
        if (messageEvent.data is String) {
          final message = messageEvent.data as String;
          if (message.contains('blocked') || message.contains('refused') || message.contains('CSP')) {
            print('[PdfInlineViewer] Detected security/CSP blocking: $message');
            if (mounted) {
              setState(() {
                _iframeBlocked = true;
              });
            }
          }
        }
      });

      return iframe;
    });
    _registered = true;
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || _iframeBlocked) {
      return Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _iframeBlocked ? 'Document cannot be embedded' : 'Failed to load document',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _iframeBlocked
                    ? 'This document has security restrictions that prevent embedding. Use the button below to view it directly.'
                    : 'The document could not be displayed in the browser',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(widget.url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_browser),
                label: Text(_iframeBlocked ? 'Open Document' : 'Open in Browser'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: HtmlElementView(viewType: _viewType)),
    );
  }
}
