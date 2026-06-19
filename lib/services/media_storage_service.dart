import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/message.dart';
import 'api_service.dart';

class MediaStorageService {
  MediaStorageService._();

  static final MediaStorageService instance = MediaStorageService._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 10),
    ),
  );
  final Map<String, Future<String?>> _downloads = {};
  final Map<String, CancelToken> _cancelTokens = {};
  Future<void> _backgroundQueue = Future<void>.value();
  int _generation = 0;

  Future<Directory> _userMediaDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final userId = _safeSegment(ApiService.currentUserId ?? 'signed_out');
    final directory = Directory(p.join(documents.path, 'media', userId));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<String> persistOutgoing({
    required File source,
    required String mediaId,
    required String mediaType,
    String? fileName,
  }) async {
    final target = await _targetFile(
      mediaId: mediaId,
      mediaType: mediaType,
      fileName: fileName ?? p.basename(source.path),
      url: null,
    );
    if (p.equals(source.path, target.path)) return target.path;
    final part = File('${target.path}.part');
    if (await part.exists()) await part.delete();
    await source.copy(part.path);
    if (await target.exists()) await target.delete();
    await part.rename(target.path);
    return target.path;
  }

  Future<String?> cacheMessage(Message message) {
    final localPath = message.localFilePath;
    if (localPath != null && localPath.isNotEmpty) {
      final local = File(localPath);
      if (local.existsSync()) return Future<String?>.value(local.path);
    }
    final url = message.fileUrl;
    if (url == null || url.isEmpty || message.type == 'text') {
      return Future<String?>.value(null);
    }
    return cacheRemote(
      url: ApiService.mediaUrl(url),
      mediaId: message.id,
      mediaType: message.type,
      fileName: message.fileName,
    );
  }

  Future<String?> cacheRemote({
    required String url,
    required String mediaId,
    required String mediaType,
    String? fileName,
  }) {
    final key = '$mediaType:$mediaId';
    return _downloads.putIfAbsent(key, () async {
      final generation = _generation;
      final cancelToken = CancelToken();
      _cancelTokens[key] = cancelToken;
      try {
        final target = await _targetFile(
          mediaId: mediaId,
          mediaType: mediaType,
          fileName: fileName,
          url: url,
        );
        if (await target.exists() && await target.length() > 0) {
          return target.path;
        }

        final part = File('${target.path}.part');
        if (await part.exists()) await part.delete();
        await _dio.download(
          url,
          part.path,
          options: Options(followRedirects: true),
          cancelToken: cancelToken,
        );
        if (generation != _generation) {
          if (await part.exists()) await part.delete();
          return null;
        }
        if (!await part.exists() || await part.length() == 0) {
          if (await part.exists()) await part.delete();
          return null;
        }
        if (await target.exists()) await target.delete();
        await part.rename(target.path);
        return target.path;
      } catch (_) {
        return null;
      } finally {
        _cancelTokens.remove(key);
        _downloads.remove(key);
      }
    });
  }

  void cacheMessagesInBackground(
    Iterable<Message> messages, {
    required FutureOr<void> Function(Message message, String path) onCached,
  }) {
    final candidates = messages.where(
      (message) =>
          message.type != 'text' && (message.fileUrl?.isNotEmpty ?? false),
    );
    _backgroundQueue = _backgroundQueue.then((_) async {
      for (final message in candidates) {
        final path = await cacheMessage(message);
        if (path != null) await onCached(message, path);
      }
    });
  }

  Future<void> deleteLocalFile(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<void> clearAllMedia() async {
    _generation++;
    for (final token in _cancelTokens.values) {
      if (!token.isCancelled) token.cancel('User media cleared');
    }
    _cancelTokens.clear();
    final documents = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(documents.path, 'media'));
    if (await root.exists()) await root.delete(recursive: true);
    _downloads.clear();
    _backgroundQueue = Future<void>.value();
  }

  Future<File> _targetFile({
    required String mediaId,
    required String mediaType,
    required String? fileName,
    required String? url,
  }) async {
    final root = await _userMediaDirectory();
    final typeDirectory = Directory(p.join(root.path, _safeSegment(mediaType)));
    if (!await typeDirectory.exists()) {
      await typeDirectory.create(recursive: true);
    }
    final extension = _extension(fileName, url);
    return File(
      p.join(typeDirectory.path, '${_safeSegment(mediaId)}$extension'),
    );
  }

  String _extension(String? fileName, String? url) {
    final fromName = p.extension(fileName ?? '');
    if (fromName.isNotEmpty && fromName.length <= 12) {
      return fromName.toLowerCase();
    }
    final uri = url == null ? null : Uri.tryParse(url);
    final fromUrl = p.extension(uri?.path ?? '');
    if (fromUrl.isNotEmpty && fromUrl.length <= 12) {
      return fromUrl.toLowerCase();
    }
    return '.bin';
  }

  String _safeSegment(String value) {
    final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty ? 'media' : safe;
  }
}
