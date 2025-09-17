// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

Future<String?> fetchPkHttpFallback(String projectId, {String region = 'us-central1'}) async {
  try {
    final url = 'https://$region-$projectId.cloudfunctions.net/getStripePublishableKeyHttp';
    final req = await html.HttpRequest.request(url, method: 'GET', requestHeaders: {'Accept': 'application/json'});
    if (req.status == 200 && req.responseText != null) {
      final json = jsonDecode(req.responseText!);
      final pk = json['publishableKey'] as String?;
      return pk;
    }
  } catch (_) {}
  return null;
}
