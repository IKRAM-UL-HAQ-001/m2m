// Cross-platform MultipartFile creation.
//
// Native builds stream from the file path (memory-efficient for large media);
// web builds read the bytes because there is no dart:io file path. The correct
// implementation is picked at compile time via conditional import so the web
// bundle never references dart:io.
export 'multipart_helper_io.dart'
    if (dart.library.html) 'multipart_helper_web.dart';
