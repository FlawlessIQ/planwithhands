import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Fallback (non-web) implementation used by conditional import.
class PdfInlineViewer extends StatelessWidget {
  final String url;

  const PdfInlineViewer({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          Text('Open PDF', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Preview not available inline on this platform. You can open it externally.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open PDF'),
          ),
        ],
      ),
    );
  }
}
