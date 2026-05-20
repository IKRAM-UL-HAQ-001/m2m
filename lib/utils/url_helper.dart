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
    final cleanBaseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    
    var cleanUrl = url;
    if (cleanUrl.startsWith('/')) {
      cleanUrl = cleanUrl.substring(1);
    }
    
    if (cleanUrl.startsWith('media/')) {
      return "$cleanBaseUrl/$cleanUrl";
    } else {
      return "$cleanBaseUrl/media/$cleanUrl";
    }
  }
}
