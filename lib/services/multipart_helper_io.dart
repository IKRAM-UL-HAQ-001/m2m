import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';

/// Native: stream the upload straight from the file path.
Future<MultipartFile> multipartFromXFile(XFile file, {String? filename}) {
  return MultipartFile.fromFile(file.path, filename: filename ?? file.name);
}
