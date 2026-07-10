import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';

/// Web: no dart:io file path exists, so read the picked bytes and upload those.
Future<MultipartFile> multipartFromXFile(XFile file, {String? filename}) async {
  final bytes = await file.readAsBytes();
  return MultipartFile.fromBytes(bytes, filename: filename ?? file.name);
}
