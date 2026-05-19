import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_status.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class StatusViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();
  StreamSubscription<Map<String, dynamic>>? _statusEventSubscription;

  bool _isLoading = false;
  String? _error;
  List<UserStatus> _myStatuses = [];
  List<StatusGroup> _contactGroups = [];

  StatusViewModel() {
    _statusEventSubscription = _socketService.statusEventStream.listen((_) {
      loadStatuses(isSilent: true);
    });
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<UserStatus> get myStatuses => _myStatuses;
  List<StatusGroup> get unseenGroups =>
      _contactGroups.where((group) => group.hasUnseen).toList();
  List<StatusGroup> get seenGroups =>
      _contactGroups.where((group) => !group.hasUnseen).toList();
  bool get hasUnseenStatuses => unseenGroups.isNotEmpty;
  bool get hasMyStatus => _myStatuses.isNotEmpty;

  Future<StatusGroup> myStatusGroup() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('user_id') ?? ApiService.currentUserId ?? 'me';
    final name = prefs.getString('user_name') ?? 'My status';
    final picture = prefs.getString('user_profile_picture');
    return StatusGroup(
      owner: StatusOwner(
        id: id,
        name: name.isEmpty ? 'My status' : name,
        profilePictureUrl: picture?.isEmpty == true ? null : picture,
      ),
      statuses: _myStatuses,
      unviewedCount: 0,
      latestStatusTime: _myStatuses.isEmpty
          ? null
          : _myStatuses.first.createdAt,
      isMine: true,
    );
  }

  Future<void> loadStatuses({bool isSilent = false}) async {
    if (!isSilent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final results = await Future.wait([
        _apiService.fetchMyStatuses(),
        _apiService.fetchStatusFeed(),
      ]);
      _myStatuses = results[0] as List<UserStatus>;
      _contactGroups = results[1] as List<StatusGroup>;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (!isSilent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> createTextStatus(
    String text, {
    String backgroundColor = '#6B00D7',
    int fontSize = 28,
    String privacy = 'all_contacts',
    List<String> userIds = const [],
  }) async {
    await _apiService.createTextStatus(
      text,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      privacy: privacy,
      userIds: userIds,
    );
    await loadStatuses();
  }

  Future<void> createMediaStatus(
    File file,
    String statusType, {
    String privacy = 'all_contacts',
    List<String> userIds = const [],
  }) async {
    await _apiService.createMediaStatus(
      file,
      statusType,
      privacy: privacy,
      userIds: userIds,
    );
    await loadStatuses();
  }

  Future<void> markViewed(String statusId) async {
    await _apiService.markStatusViewed(statusId);
    _contactGroups = _contactGroups.map((group) {
      final updated = group.statuses.map((status) {
        if (status.id != statusId) return status;
        return UserStatus(
          id: status.id,
          statusType: status.statusType,
          textContent: status.textContent,
          mediaUrl: status.mediaUrl,
          thumbnailUrl: status.thumbnailUrl,
          backgroundColor: status.backgroundColor,
          fontSize: status.fontSize,
          duration: status.duration,
          createdAt: status.createdAt,
          expiresAt: status.expiresAt,
          isViewed: true,
          viewCount: status.viewCount,
        );
      }).toList();
      final unseen = updated.where((status) => !status.isViewed).length;
      return group.copyWith(statuses: updated, unviewedCount: unseen);
    }).toList();
    notifyListeners();
  }

  Future<List<StatusViewer>> fetchViewers(String statusId) {
    return _apiService.fetchStatusViewers(statusId);
  }

  Future<void> deleteStatus(String statusId) async {
    await _apiService.deleteStatus(statusId);
    _myStatuses = _myStatuses.where((status) => status.id != statusId).toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _statusEventSubscription?.cancel();
    super.dispose();
  }
}
