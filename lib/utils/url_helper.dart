import '../services/api_service.dart';

class UrlHelper {
  static String getBaseUrl() {
    // Extract base URL (everything before /api or /auth)
    final apiBase = ApiService.baseUrl;
    return apiBase.replaceAll('/api', '');
  }

  static String fixUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    
    final baseUrl = getBaseUrl();
    if (url.startsWith('/')) {
      return "$baseUrl$url";
    } else {
      return "$baseUrl/media/$url";
    }
  }
}
