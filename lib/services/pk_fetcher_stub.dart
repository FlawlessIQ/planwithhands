Future<String?> fetchPkHttpFallback(String projectId, {String region = 'us-central1'}) async {
  // Not available on non-web; return null to indicate no fallback
  return null;
}
