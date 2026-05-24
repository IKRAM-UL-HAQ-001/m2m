import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import '../services/websocket_service.dart';
import '../utils/constants.dart';
import '../utils/responsive.dart';
import '../viewmodels/chat_viewmodel.dart';
import '../viewmodels/call_viewmodel.dart';
import '../widgets/forward_contact_picker_sheet.dart';
import '../widgets/profile_quick_modal.dart';
import 'chat/widgets/chat_input_bar.dart';
import 'chat/widgets/message_list.dart';
import 'calls/outgoing_call_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final Chat chat;
  const ChatDetailScreen({super.key, required this.chat});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with TickerProviderStateMixin {
  static const double _emojiPickerHeight = 280;
  static const int _maxMessageScrollKeys = 50;

  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();
  final AppDatabase _db = AppDatabase();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final Map<String, GlobalKey> _messageKeys = {};

  bool _showSendIcon = false;
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isRecording = false;
  bool _isLocked = false;
  bool _isCancelling = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  Offset _recordingStartPos = Offset.zero;
  final ValueNotifier<Offset> _recordingCurrentOffset = ValueNotifier<Offset>(
    Offset.zero,
  );
  late AnimationController _pulseController;
  late AnimationController _blinkController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _blinkAnimation;

  bool _showEmojiPicker = false;
  Widget? _cachedEmojiPicker;
  Message? _replyingToMessage;
  String? _highlightedMessageId;

  bool _isOtherTyping = false;
  Timer? _typingClearTimer;
  Timer? _typingDebounceTimer;
  Timer? _highlightTimer;
  bool _hasNotifiedTyping = false;

  Set<String> _downloadedUrls = {};
  String? _currentChatId;
  late final ChatViewModel _chatViewModel;
  final Set<String> _recentSocketMessageKeys = {};
  final List<String> _recentSocketMessageOrder = [];
  final Set<String> _readMarkedMessageIds = {};
  bool _hasMarkedOpenChatRead = false;
  static const int _maxRecentSocketMessages = 200;

  StreamSubscription<Message>? _socketSubscription;
  StreamSubscription<MessageStatusUpdate>? _statusSubscription;
  StreamSubscription<Map<String, dynamic>>? _typingSubscription;
  StreamSubscription<Map<String, dynamic>>? _editSubscription;
  StreamSubscription<Map<String, dynamic>>? _deleteSubscription;
  StreamSubscription<Map<String, dynamic>>? _reactionSubscription;

  @override
  void initState() {
    super.initState();
    _chatViewModel = context.read<ChatViewModel>();
    _currentChatId = widget.chat.id;
    _chatViewModel.setActiveChat(_currentChatId);
    SocketService().setActiveChatId(_currentChatId);
    NotificationService.setActiveChatId(_currentChatId);
    NotificationService.setActiveChatParticipantId(widget.chat.receiverId);
    _loadDownloadedFiles();
    _loadMessages();
    _listenToSocket();
    if (!_currentChatId!.startsWith('new_')) {
      SocketService().sendChatOpened(_currentChatId!);
      _markCurrentChatRead();
    }
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmojiPicker) {
        setState(() => _showEmojiPicker = false);
      }
    });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _blinkAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(_blinkController);
  }

  void _listenToSocket() {
    _socketSubscription = SocketService().messageStream.listen((msg) {
      if (!mounted || msg.chatId != _currentChatId) {
        return;
      }
      if (_isDuplicateSocketMessage(msg)) {
        return;
      }
      final changed = _upsertMessage(msg);
      if (changed) {
        unawaited(_db.upsertMessage(msg));
        setState(() {});
        if (!msg.isMe) {
          _markCurrentChatRead(messageId: msg.id);
        }
      }
    });
    _statusSubscription = SocketService().messageStatusStream.listen((status) {
      if (status.chatId == _currentChatId && mounted) {
        final changed = _applyStatus(status);
        for (final id
            in status.messageIds.isEmpty
                ? [status.messageId]
                : status.messageIds) {
          unawaited(_db.updateMessageStatus(id, status.deliveryState));
        }
        if (changed) setState(() {});
      }
    });
    _editSubscription = SocketService().messageEditStream.listen((data) {
      if (data['chat_id']?.toString() == _currentChatId && mounted) {
        final changed = _applyEdit(data);
        if (changed) {
          final messageId = data['message_id']?.toString();
          final message = _messageById(messageId);
          if (message != null) unawaited(_db.upsertMessage(message));
          setState(() {});
        }
      }
    });
    _deleteSubscription = SocketService().messageDeleteStream.listen((data) {
      if (data['chat_id']?.toString() == _currentChatId && mounted) {
        final changed = _applyDelete(data);
        if (changed) {
          final messageId = data['message_id']?.toString();
          final message = _messageById(messageId);
          if (message != null) unawaited(_db.upsertMessage(message));
          setState(() {});
        }
      }
    });
    _reactionSubscription = SocketService().reactionStream.listen((data) {
      if (data['chat_id']?.toString() == _currentChatId && mounted) {
        final changed = _applyReaction(data);
        if (changed) {
          final messageId = data['message_id']?.toString();
          final message = _messageById(messageId);
          if (message != null) unawaited(_db.upsertMessage(message));
          setState(() {});
        }
      }
    });
    _typingSubscription = SocketService().typingStream.listen((data) {
      final chatId = data['chat_id']?.toString();
      final userId = data['user_id']?.toString();
      final isTyping = data['is_typing'] == true;
      if (chatId == _currentChatId &&
          userId != ApiService.currentUserId &&
          mounted) {
        if (_isOtherTyping == isTyping) return;
        setState(() => _isOtherTyping = isTyping);
        _typingClearTimer?.cancel();
        if (isTyping) {
          _typingClearTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) setState(() => _isOtherTyping = false);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _statusSubscription?.cancel();
    _typingSubscription?.cancel();
    _editSubscription?.cancel();
    _deleteSubscription?.cancel();
    _reactionSubscription?.cancel();
    _typingClearTimer?.cancel();
    _typingDebounceTimer?.cancel();
    _highlightTimer?.cancel();
    _recordingTimer?.cancel();
    _pulseController.dispose();
    _blinkController.dispose();
    _recordingCurrentOffset.dispose();
    if (_chatViewModel.activeChatId == _currentChatId) {
      _chatViewModel.setActiveChat(null);
    }
    if (NotificationService.isActiveChat(_currentChatId)) {
      NotificationService.setActiveChatId(null);
      NotificationService.setActiveChatParticipantId(null);
    }
    SocketService().setActiveChatId(null);
    _audioRecorder.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMessages() async {
    if (_currentChatId == null || _currentChatId!.startsWith('new_')) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final cachedMessages = await _db.getCachedMessages(_currentChatId!);
      if (mounted && cachedMessages.isNotEmpty) {
        setState(() {
          _messages = cachedMessages;
          _isLoading = false;
          _pruneMessageKeys();
        });
      }
    } catch (e) {
      debugPrint('Error loading cached messages: $e');
    }
    try {
      final messages = await _apiService.getMessages(_currentChatId!);
      unawaited(_db.upsertMessages(_currentChatId!, messages));
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
          _pruneMessageKeys();
        });
        _markCurrentChatRead();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDownloadedFiles() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _downloadedUrls = (prefs.getStringList('downloaded_urls') ?? [])
            .toSet();
      });
    }
  }

  Future<void> _markAsDownloaded(String url) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _downloadedUrls.add(url));
    await prefs.setStringList('downloaded_urls', _downloadedUrls.toList());
  }

  bool _upsertMessage(Message message) {
    final existingIndex = _messages.indexWhere(
      (m) => m.id == message.id || m.clientUuid == message.clientUuid,
    );
    if (existingIndex == -1) {
      _messages.insert(0, message);
      _pruneMessageKeys();
      return true;
    }

    if (_messages[existingIndex] == message) {
      return false;
    } else {
      _messages[existingIndex] = message;
    }
    _pruneMessageKeys();
    return true;
  }

  Message? _messageById(String? messageId) {
    if (messageId == null || messageId.isEmpty) return null;
    final index = _messages.indexWhere((m) => m.id == messageId);
    return index == -1 ? null : _messages[index];
  }

  bool _isDuplicateSocketMessage(Message message) {
    final key = '${message.chatId}:${message.clientUuid}:${message.id}';
    if (_recentSocketMessageKeys.contains(key)) return true;
    _recentSocketMessageKeys.add(key);
    _recentSocketMessageOrder.add(key);
    if (_recentSocketMessageOrder.length > _maxRecentSocketMessages) {
      final oldest = _recentSocketMessageOrder.removeAt(0);
      _recentSocketMessageKeys.remove(oldest);
    }
    return false;
  }

  void _markCurrentChatRead({String? messageId}) {
    final chatId = _currentChatId;
    if (chatId == null || chatId.startsWith('new_')) return;
    if (messageId != null) {
      if (!_readMarkedMessageIds.add(messageId)) return;
    } else {
      if (_hasMarkedOpenChatRead) return;
      _hasMarkedOpenChatRead = true;
    }
    _chatViewModel.markChatRead(chatId);
    unawaited(_db.markMessagesRead(chatId));
    _apiService.markChatRead(chatId).catchError((_) {});
  }

  GlobalKey? _messageTargetKey(String messageId) {
    if (messageId != _highlightedMessageId) return null;
    return _messageKeys.putIfAbsent(messageId, GlobalKey.new);
  }

  void _pruneMessageKeys({String? keepMessageId}) {
    if (_messageKeys.isEmpty) return;
    final loadedIds = _messages.map((message) => message.id).toSet();
    final keepId = keepMessageId ?? _highlightedMessageId;
    _messageKeys.removeWhere((id, _) {
      if (!loadedIds.contains(id)) return true;
      return keepId == null || id != keepId;
    });
    while (_messageKeys.length > _maxMessageScrollKeys) {
      _messageKeys.remove(_messageKeys.keys.first);
    }
  }

  Future<void> _scrollToMessage(String? messageId) async {
    if (messageId == null || messageId.isEmpty) return;
    final index = _messages.indexWhere((message) => message.id == messageId);
    if (index == -1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original message is not loaded')),
      );
      return;
    }

    _focusNode.unfocus();
    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
    }
    _highlightMessage(messageId);

    final key = _messageKeys[messageId];
    final targetContext = key?.currentContext;
    if (targetContext != null) {
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.35,
      );
      return;
    }

    if (!_scrollController.hasClients) return;
    final estimatedOffset = (index * 96.0).clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );
    await _scrollController.animateTo(
      estimatedOffset,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _messageKeys[messageId]?.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: 0.35,
      );
    });
  }

  void _highlightMessage(String messageId) {
    _highlightTimer?.cancel();
    _messageKeys.putIfAbsent(messageId, GlobalKey.new);
    _pruneMessageKeys(keepMessageId: messageId);
    setState(() => _highlightedMessageId = messageId);
    _highlightTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted && _highlightedMessageId == messageId) {
        setState(() {
          _highlightedMessageId = null;
          _pruneMessageKeys();
        });
      }
    });
  }

  bool _applyStatus(MessageStatusUpdate status) {
    var changed = false;
    final ids = status.messageIds.isEmpty
        ? [status.messageId]
        : status.messageIds;
    for (final id in ids) {
      final index = _messages.indexWhere((m) => m.id == id);
      if (index == -1) continue;
      if (_messages[index].deliveryState == status.deliveryState) continue;
      _messages[index] = _messages[index].copyWith(
        deliveryState: status.deliveryState,
      );
      changed = true;
    }
    return changed;
  }

  bool _applyEdit(Map<String, dynamic> data) {
    final index = _messages.indexWhere(
      (m) => m.id == data['message_id']?.toString(),
    );
    if (index == -1) return false;
    final nextText = data['new_content']?.toString() ?? _messages[index].text;
    final nextEditedAt =
        DateTime.tryParse(data['edited_at']?.toString() ?? '')?.toLocal() ??
        DateTime.now();
    if (_messages[index].text == nextText &&
        _messages[index].editedAt == nextEditedAt) {
      return false;
    }
    _messages[index] = _messages[index].copyWith(
      text: nextText,
      editedAt: nextEditedAt,
    );
    return true;
  }

  bool _applyDelete(Map<String, dynamic> data) {
    final index = _messages.indexWhere(
      (m) => m.id == data['message_id']?.toString(),
    );
    if (index == -1) return false;
    if (_messages[index].isDeletedForEveryone &&
        _messages[index].text.isEmpty &&
        (_messages[index].fileUrl == null || _messages[index].fileUrl == '')) {
      return false;
    }
    _messages[index] = _messages[index].copyWith(
      text: '',
      isDeletedForEveryone: true,
      fileUrl: '',
    );
    _pruneMessageKeys();
    return true;
  }

  bool _applyReaction(Map<String, dynamic> data) {
    final index = _messages.indexWhere(
      (m) => m.id == data['message_id']?.toString(),
    );
    if (index == -1) return false;
    final emoji = data['emoji']?.toString();
    final userId = data['user_id']?.toString();
    if (emoji == null || userId == null) return false;
    final reactions = Map<String, List<String>>.from(
      _messages[index].reactions.map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      ),
    );
    if (data['action'] == 'remove') {
      if (!(reactions[emoji]?.contains(userId) ?? false)) return false;
      reactions[emoji]?.remove(userId);
      if (reactions[emoji]?.isEmpty ?? false) reactions.remove(emoji);
    } else {
      reactions.putIfAbsent(emoji, () => []);
      if (reactions[emoji]!.contains(userId)) return false;
      if (!reactions[emoji]!.contains(userId)) reactions[emoji]!.add(userId);
    }
    _messages[index] = _messages[index].copyWith(reactions: reactions);
    return true;
  }

  void _onTextChanged(String val) {
    _syncSendIcon();
    _sendTypingNotification(true);
  }

  void _syncSendIcon() {
    final shouldShow = _messageController.text.trim().isNotEmpty;
    if (_showSendIcon == shouldShow) return;
    setState(() => _showSendIcon = shouldShow);
  }

  void _sendTypingNotification(bool isTyping) {
    if (_currentChatId == null || _currentChatId!.startsWith('new_')) return;
    if (isTyping) {
      if (!_hasNotifiedTyping) {
        _hasNotifiedTyping = true;
        _apiService.sendTyping(_currentChatId!, true).catchError((_) {});
      }
      _typingDebounceTimer?.cancel();
      _typingDebounceTimer = Timer(const Duration(seconds: 3), () {
        _hasNotifiedTyping = false;
        _apiService.sendTyping(_currentChatId!, false).catchError((_) {});
      });
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await PermissionService.requestMicrophone(context);
    if (!hasPermission) return;
    try {
      final dir = await getTemporaryDirectory();
      _recordingPath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _recordingPath!,
      );
      HapticFeedback.mediumImpact();
      _pulseController.repeat(reverse: true);
      _blinkController.repeat(reverse: true);
      if (mounted) {
        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() => _recordingDuration += const Duration(seconds: 1));
          }
        });
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    _blinkController.stop();
    _blinkController.reset();
    try {
      final recordedDuration = _recordingDuration;
      final path = await _audioRecorder.stop();
      if (mounted) {
        _recordingCurrentOffset.value = Offset.zero;
        setState(() {
          _isRecording = false;
          _isLocked = false;
          _isCancelling = false;
          _recordingDuration = Duration.zero;
        });
      }
      if (path != null) {
        final audioFile = File(path);
        var size = await audioFile.exists() ? await audioFile.length() : 0;
        if (size == 0) {
          await Future.delayed(const Duration(milliseconds: 300));
          size = await audioFile.exists() ? await audioFile.length() : 0;
        }
        if (size == 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Voice message was empty')),
            );
          }
          return;
        }
        _sendFileMessage(
          audioFile,
          type: 'audio',
          duration: recordedDuration.inMilliseconds / 1000.0,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isLocked = false;
          _isCancelling = false;
        });
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    _blinkController.stop();
    _blinkController.reset();
    await _audioRecorder.stop();
    if (mounted) {
      _recordingCurrentOffset.value = Offset.zero;
      setState(() {
        _isRecording = false;
        _isLocked = false;
        _isCancelling = false;
        _recordingDuration = Duration.zero;
      });
    }
  }

  void _lockRecording() {
    if (_isLocked || !_isRecording) return;
    HapticFeedback.heavyImpact();
    _recordingCurrentOffset.value = Offset.zero;
    setState(() {
      _isLocked = true;
      _isCancelling = false;
    });
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final clientUuid = ApiService.createClientUuid();
    _messageController.clear();
    setState(() => _showSendIcon = false);
    HapticFeedback.lightImpact();

    final replyId = _replyingToMessage?.id;
    setState(() => _replyingToMessage = null);

    setState(() {
      final pendingMessage = Message(
        id: clientUuid,
        clientUuid: clientUuid,
        text: text,
        senderId: ApiService.currentUserId ?? '0',
        time: DateTime.now(),
        isMe: true,
        chatId: _currentChatId ?? widget.chat.id,
        deliveryState: DeliveryState.pending,
      );
      _messages.insert(0, pendingMessage);
      if (!pendingMessage.chatId.startsWith('new_')) {
        unawaited(_db.upsertMessage(pendingMessage));
      }
      _pruneMessageKeys();
    });
    _scrollToBottom();

    try {
      final message = await _apiService.sendMessage(
        widget.chat.receiverId,
        text,
        clientUuid: clientUuid,
        replyTo: replyId,
      );
      if (_currentChatId!.startsWith('new_')) {
        _currentChatId = message.chatId;
        _chatViewModel.setActiveChat(_currentChatId);
        SocketService().setActiveChatId(_currentChatId);
      }
      if (mounted) {
        final changed = _upsertMessage(message);
        unawaited(_db.upsertMessage(message));
        if (changed) setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.clientUuid == clientUuid);
          if (index != -1) {
            _messages[index] = _messages[index].copyWith(
              deliveryState: DeliveryState.failed,
            );
            if (!_messages[index].chatId.startsWith('new_')) {
              unawaited(_db.upsertMessage(_messages[index]));
            }
          }
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    }
  }

  void _sendFileMessage(File file, {String? type, double? duration}) async {
    final clientUuid = ApiService.createClientUuid();
    final pendingText = switch (type) {
      'audio' => '🎤 Voice message',
      'image' => '📷 Photo',
      'video' => '🎬 Video',
      _ => '📎 File',
    };
    if (mounted) {
      setState(() {
        final pendingMessage = Message(
          id: clientUuid,
          clientUuid: clientUuid,
          text: pendingText,
          senderId: ApiService.currentUserId ?? '0',
          time: DateTime.now(),
          isMe: true,
          chatId: _currentChatId ?? widget.chat.id,
          type: type ?? 'document',
          deliveryState: DeliveryState.pending,
        );
        _messages.insert(0, pendingMessage);
        if (!pendingMessage.chatId.startsWith('new_')) {
          unawaited(_db.upsertMessage(pendingMessage));
        }
        _pruneMessageKeys();
      });
      _scrollToBottom();
    }
    try {
      final message = await _apiService.sendMessage(
        widget.chat.receiverId,
        '[File]',
        clientUuid: clientUuid,
        file: file,
        type: type,
        replyTo: _replyingToMessage?.id,
        duration: duration,
      );
      if (mounted) {
        setState(() {
          _replyingToMessage = null;
          if (_currentChatId!.startsWith('new_')) {
            _currentChatId = message.chatId;
            _chatViewModel.setActiveChat(_currentChatId);
          }
          _upsertMessage(message);
          unawaited(_db.upsertMessage(message));
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.clientUuid == clientUuid);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(
              deliveryState: DeliveryState.failed,
            );
            if (!_messages[idx].chatId.startsWith('new_')) {
              unawaited(_db.upsertMessage(_messages[idx]));
            }
          }
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to send file')));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final hasCam = await PermissionService.requestCamera(context);
      if (!hasCam) return;
    } else {
      final hasStorage = await PermissionService.requestPhotos(context);
      if (!hasStorage) return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) _sendFileMessage(File(picked.path), type: 'image');
  }

  void _pickVideo() async {
    final hasStorage = await PermissionService.requestVideos(context);
    if (!hasStorage) return;
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) _sendFileMessage(File(picked.path), type: 'video');
  }

  void _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
    );
    if (result != null && result.files.single.path != null) {
      _sendFileMessage(File(result.files.single.path!));
    }
  }

  void _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      _sendFileMessage(File(result.files.single.path!), type: 'audio');
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _attachItem(
                  Icons.insert_drive_file,
                  Colors.indigo,
                  'Document',
                  _pickFile,
                ),
                _attachItem(
                  Icons.camera_alt,
                  Colors.pink,
                  'Camera',
                  () => _pickImage(ImageSource.camera),
                ),
                _attachItem(
                  Icons.photo_library,
                  Colors.purple,
                  'Gallery',
                  () => _pickImage(ImageSource.gallery),
                ),
                _attachItem(Icons.videocam, Colors.orange, 'Video', _pickVideo),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _attachItem(Icons.audiotrack, Colors.teal, 'Audio', _pickAudio),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachItem(
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color,
            child: Icon(icon, size: 26, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(ApiService.mediaUrl(url));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open file')));
    }
  }

  void _openMediaPreview(Message message) {
    if (message.fileUrl == null || message.fileUrl!.isEmpty) return;
    final url = ApiService.mediaUrl(message.fileUrl);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaPreviewScreen(
          url: url,
          isVideo: message.type == 'video' || _isVideoUrl(url),
          caption: message.text == '[File]' ? null : message.text,
          heroTag: 'media-${message.id}',
        ),
      ),
    );
  }

  Future<void> _downloadAndSaveImage(String url) async {
    try {
      if (Platform.isAndroid) {
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) await Gal.requestAccess();
      }
      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Dio().download(url, path);
      await Gal.putImage(path);
      await _markAsDownloaded(url);
      final f = File(path);
      if (await f.exists()) await f.delete();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Image saved to gallery')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showMessageOptions(Message message) {
    const quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final emoji in quickReactions)
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.pop(ctx);
                        _reactToMessage(message, emoji);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyingToMessage = message);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _focusNode.requestFocus();
                });
              },
            ),
            if (message.text.isNotEmpty && message.text != '[File]')
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy Text'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.text));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
            if (message.isMe &&
                message.type == 'text' &&
                !message.isDeletedForEveryone &&
                DateTime.now().difference(message.time) <
                    const Duration(minutes: 15))
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditDialog(message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Delete for me',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _deleteMessage(message, 'for_me');
              },
            ),
            if (message.isMe)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  'Delete for everyone',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(message, 'for_everyone');
                },
              ),
            ListTile(
              leading: const Icon(Icons.forward),
              title: const Text('Forward'),
              onTap: () {
                Navigator.pop(ctx);
                _forwardMessage(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.star_border),
              title: const Text('Star message'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message starred locally')),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showReactionUsers(String emoji, List<String> userIds) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$emoji: ${userIds.join(', ')}')));
  }

  Future<void> _deleteMessage(Message message, String deleteType) async {
    try {
      await _apiService.deleteMessage(message.id, deleteType);
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index == -1) return;
        if (deleteType == 'for_me') {
          unawaited(
            _db.upsertMessage(_messages[index].copyWith(isDeletedForMe: true)),
          );
          _messages.removeAt(index);
          _pruneMessageKeys();
        } else {
          _messages[index] = _messages[index].copyWith(
            text: '',
            isDeletedForEveryone: true,
            fileUrl: '',
          );
          unawaited(_db.upsertMessage(_messages[index]));
          _pruneMessageKeys(keepMessageId: message.id);
        }
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _showEditDialog(Message message) async {
    final controller = TextEditingController(text: message.text);
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newText == null || newText.isEmpty || newText == message.text) return;
    try {
      await _apiService.editMessage(message.id, newText);
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            text: newText,
            editedAt: DateTime.now(),
          );
          unawaited(_db.upsertMessage(_messages[index]));
        }
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _reactToMessage(Message message, String emoji) async {
    try {
      await _apiService.reactToMessage(message.id, emoji);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _forwardMessage(Message message) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ForwardContactPickerSheet(
        message: message,
        onContactsSelected: (chatIds) async {
          Navigator.pop(context);
          await _sendForwardedMessage(message, chatIds);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                chatIds.length == 1
                    ? 'Message forwarded'
                    : 'Message forwarded to ${chatIds.length} chats',
              ),
              backgroundColor: AppColors.primaryColor,
            ),
          );
        },
      ),
    );
  }

  Future<void> _sendForwardedMessage(
    Message message,
    List<String> chatIds,
  ) async {
    for (final chatId in chatIds) {
      await _apiService.forwardMessage(
        originalMessageId: message.id,
        toChatId: chatId,
      );
    }
  }

  // ── helpers ──────────────────────────────────────────────────

  bool _isImageUrl(String url) {
    final l = url.toLowerCase().split('?').first;
    return l.endsWith('.jpg') ||
        l.endsWith('.jpeg') ||
        l.endsWith('.png') ||
        l.endsWith('.gif') ||
        l.endsWith('.webp');
  }

  bool _isVideoUrl(String url) {
    final l = url.toLowerCase().split('?').first;
    return l.endsWith('.mp4') ||
        l.endsWith('.mov') ||
        l.endsWith('.avi') ||
        l.endsWith('.mkv') ||
        l.endsWith('.3gp') ||
        l.endsWith('.webm');
  }

  // ── build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: _buildAppBar(),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  _focusNode.unfocus();
                  if (_showEmojiPicker) {
                    setState(() => _showEmojiPicker = false);
                  }
                },
                child: _buildChatArea(),
              ),
            ),
            _buildComposerArea(),
            if (_showEmojiPicker)
              RepaintBoundary(
                child: SizedBox(
                  height: _emojiPickerHeight,
                  child: _buildEmojiPicker(),
                ),
              ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primaryColor,
      iconTheme: const IconThemeData(color: Colors.white),
      titleSpacing: 0,
      title: InkWell(
        onTap: _showProfileQuickModal,
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: widget.chat.avatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(
                          ApiService.mediaUrl(widget.chat.avatarUrl),
                        )
                      : null,
                  child: widget.chat.avatarUrl.isEmpty
                      ? Icon(Icons.person, size: 20, color: Colors.grey[600])
                      : null,
                ),
                if (widget.chat.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.chat.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_isOtherTyping)
                    const Text(
                      'typing...',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    )
                  else if (widget.chat.isOnline)
                    const Text(
                      'online',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        Consumer<CallViewModel>(
          builder: (_, callViewModel, _) {
            final canStartCall = callViewModel.canStartCall;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Audio call',
                  icon: const Icon(Icons.call, color: Colors.white),
                  onPressed: canStartCall ? () => _startCall('audio') : null,
                ),
                IconButton(
                  tooltip: 'Video call',
                  icon: const Icon(Icons.videocam, color: Colors.white),
                  onPressed: canStartCall ? () => _startCall('video') : null,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _startCall(String callType) async {
    final receiverId = int.tryParse(widget.chat.receiverId);
    if (receiverId == null) {
      _showErrorSnackBar('Unable to start call for this contact');
      return;
    }

    final callViewModel = context.read<CallViewModel>();
    if (!callViewModel.canStartCall) {
      _showErrorSnackBar('You are already in a call');
      return;
    }
    final call = await callViewModel.startCall(
      receiverId: receiverId,
      callType: callType,
    );

    if (!mounted) return;

    if (call == null) {
      _showErrorSnackBar(callViewModel.errorMessage ?? 'Unable to start call');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: OutgoingCallScreen.routeName),
        builder: (_) => const OutgoingCallScreen(),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showProfileQuickModal() {
    ProfileQuickModal.show(
      context,
      userId: widget.chat.receiverId,
      name: widget.chat.name,
      phone: widget.chat.phone,
      about: widget.chat.about,
      avatarUrl: widget.chat.avatarUrl,
      isOnline: widget.chat.isOnline,
      onMessage: () {},
    );
  }

  Widget _buildChatArea() {
    return MessageList(
      messages: _messages,
      isLoading: _isLoading,
      scrollController: _scrollController,
      highlightedMessageId: _highlightedMessageId,
      targetKeyForId: _messageTargetKey,
      downloadedUrls: _downloadedUrls,
      onLongPressMessage: _showMessageOptions,
      onReplyTap: _scrollToMessage,
      onOpenMediaPreview: _openMediaPreview,
      onDownloadImage: _downloadAndSaveImage,
      onOpenFile: _openFile,
      onShowReactionUsers: _showReactionUsers,
    );
  }

  String _replySummary({
    required String? text,
    required String? type,
    required String? fileName,
  }) {
    final cleanText = (text ?? '').trim();
    if (cleanText.isNotEmpty && cleanText != '[File]') return cleanText;
    switch (type) {
      case 'image':
        return 'Photo';
      case 'video':
        return 'Video';
      case 'audio':
        return 'Voice message';
      case 'document':
        return fileName?.isNotEmpty == true ? fileName! : 'Document';
      default:
        return cleanText.isNotEmpty ? cleanText : 'Message';
    }
  }

  Widget _buildReplyMediaThumb({
    required String? type,
    required String? fileUrl,
    required String? thumbnailUrl,
  }) {
    final isImage =
        type == 'image' || (fileUrl != null && _isImageUrl(fileUrl));
    final isVideo =
        type == 'video' || (fileUrl != null && _isVideoUrl(fileUrl));
    final hasThumbnail = thumbnailUrl != null && thumbnailUrl.isNotEmpty;
    final previewUrl = ApiService.mediaUrl(
      hasThumbnail || isImage ? (thumbnailUrl ?? fileUrl) : null,
    );

    if (previewUrl.isNotEmpty && (isImage || isVideo)) {
      return _replyImageTile(
        imageUrl: previewUrl,
        showPlay: isVideo,
        fallbackType: type,
      );
    }
    if (isVideo) return _replyVideoTile();
    return _replyIcon(type);
  }

  Widget _replyImageTile({
    required String imageUrl,
    required bool showPlay,
    required String? fallbackType,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            width: 44,
            height: 44,
            memCacheWidth: 88,
            memCacheHeight: 88,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => _replyIcon(fallbackType),
          ),
          if (showPlay) _replyPlayBadge(),
        ],
      ),
    );
  }

  Widget _replyVideoTile() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF202124),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.videocam,
            size: 22,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          _replyPlayBadge(),
        ],
      ),
    );
  }

  Widget _replyPlayBadge() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
    );
  }

  Widget _replyIcon(String? type) {
    final icon = switch (type) {
      'image' => Icons.image,
      'video' => Icons.videocam,
      'audio' => Icons.mic,
      'document' => Icons.insert_drive_file,
      _ => Icons.reply,
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Icon(icon, size: 22, color: Colors.black45),
    );
  }

  // ── composer ─────────────────────────────────────────────────

  Widget _buildComposerArea() {
    return ChatInputBar(
      messageController: _messageController,
      focusNode: _focusNode,
      showEmojiPicker: _showEmojiPicker,
      showSendIcon: _showSendIcon,
      isRecording: _isRecording,
      isLocked: _isLocked,
      isCancelling: _isCancelling,
      recordingDuration: _recordingDuration,
      recordingCurrentOffset: _recordingCurrentOffset,
      blinkAnimation: _blinkAnimation,
      pulseAnimation: _pulseAnimation,
      replyingToMessage: _replyingToMessage,
      replyAuthorName: widget.chat.name,
      replySummaryBuilder: (message) => _replySummary(
        text: message.text,
        type: message.type,
        fileName: message.fileName,
      ),
      replyMediaThumbBuilder: (message) => _buildReplyMediaThumb(
        type: message.type,
        fileUrl: message.fileUrl,
        thumbnailUrl: message.thumbnailUrl,
      ),
      onTextChanged: _onTextChanged,
      onToggleEmojiPicker: _toggleEmojiPicker,
      onShowAttachmentOptions: _showAttachmentOptions,
      onOpenCamera: () => _pickImage(ImageSource.camera),
      onCancelReply: () => setState(() => _replyingToMessage = null),
      onSendMessage: _sendMessage,
      onStartRecordingPointerDown: _handleRecordingPointerDown,
      onRecordingPointerMove: _handleRecordingPointerMove,
      onRecordingPointerUp: _handleRecordingPointerUp,
      onCancelLockedRecording: () {
        HapticFeedback.lightImpact();
        _cancelRecording();
      },
      onStopRecording: _stopRecording,
    );
  }

  void _handleRecordingPointerDown(PointerDownEvent event) {
    _recordingCurrentOffset.value = Offset.zero;
    setState(() {
      _recordingStartPos = event.position;
      _isCancelling = false;
    });
    _startRecording();
  }

  void _handleRecordingPointerMove(PointerMoveEvent event) {
    final offset = event.position - _recordingStartPos;
    _recordingCurrentOffset.value = offset;
    if (offset.dx < -100) {
      HapticFeedback.lightImpact();
      _cancelRecording();
    } else if (offset.dy < -120) {
      _lockRecording();
    } else if (offset.dx < -60) {
      if (!_isCancelling) setState(() => _isCancelling = true);
    } else {
      if (_isCancelling) setState(() => _isCancelling = false);
    }
  }

  void _handleRecordingPointerUp(PointerUpEvent event) {
    final offset = event.position - _recordingStartPos;
    if (offset.dx < -60 || _isCancelling) {
      HapticFeedback.lightImpact();
      _cancelRecording();
    } else {
      _stopRecording();
    }
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    } else {
      _focusNode.unfocus();
      setState(() => _showEmojiPicker = true);
    }
  }

  Widget _buildEmojiPicker() {
    _cachedEmojiPicker ??= EmojiPicker(
      textEditingController: _messageController,
      onEmojiSelected: (_, emoji) {
        _syncSendIcon();
      },
      onBackspacePressed: () {
        _syncSendIcon();
      },
      config: Config(
        height: _emojiPickerHeight,
        checkPlatformCompatibility: false,
        emojiViewConfig: EmojiViewConfig(
          backgroundColor: Colors.white,
          emojiSizeMax:
              28 *
              (foundation.defaultTargetPlatform == TargetPlatform.iOS
                  ? 1.2
                  : 1.0),
        ),
        bottomActionBarConfig: const BottomActionBarConfig(
          enabled: true,
          backgroundColor: Colors.white,
        ),
        categoryViewConfig: const CategoryViewConfig(
          indicatorColor: AppColors.primaryColor,
          iconColor: Colors.grey,
          iconColorSelected: AppColors.primaryColor,
        ),
      ),
    );

    // Isolate from changing keyboard view insets to avoid unnecessary rebuilds during keyboard animation
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        viewInsets: EdgeInsets.zero,
        viewPadding: EdgeInsets.zero,
        padding: EdgeInsets.zero,
      ),
      child: _cachedEmojiPicker!,
    );
  }
}

class MediaPreviewScreen extends StatefulWidget {
  final String url;
  final bool isVideo;
  final String? caption;
  final String heroTag;

  const MediaPreviewScreen({
    super.key,
    required this.url,
    required this.isVideo,
    required this.heroTag,
    this.caption,
  });

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  VideoPlayerController? _videoController;
  Future<void>? _videoFuture;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
      );
      _videoController = controller;
      _videoFuture = controller.initialize().then((_) {
        controller.play();
        if (mounted) setState(() => _isPlaying = true);
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() => _isPlaying = controller.value.isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: widget.isVideo ? _buildVideo() : _buildImage(),
              ),
            ),
            if (widget.caption != null && widget.caption!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  widget.caption!,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    return Hero(
      tag: widget.heroTag,
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: CachedNetworkImage(
          imageUrl: widget.url,
          fit: BoxFit.contain,
          placeholder: (context, url) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorWidget: (context, url, error) =>
              const Icon(Icons.broken_image, color: Colors.white54, size: 56),
        ),
      ),
    );
  }

  Widget _buildVideo() {
    final controller = _videoController;
    if (controller == null || _videoFuture == null) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<void>(
      future: _videoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const CircularProgressIndicator(color: Colors.white);
        }
        if (!controller.value.isInitialized) {
          return const Icon(
            Icons.videocam_off,
            color: Colors.white54,
            size: 56,
          );
        }
        return GestureDetector(
          onTap: _togglePlayback,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
              if (!_isPlaying)
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
