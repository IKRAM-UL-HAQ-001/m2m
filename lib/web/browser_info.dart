// Cross-platform "what device am I" label for the linked-devices feature.
// On web this parses the browser's userAgent ("Chrome on Linux"); on native
// platforms (where this code path is never used) it returns a stub.
export 'browser_info_stub.dart' if (dart.library.html) 'browser_info_web.dart';
