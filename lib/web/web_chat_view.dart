import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../utils/constants.dart';
import '../widgets/forward_contact_picker_sheet.dart';
import 'web_chat_viewmodel.dart';
import 'web_media_viewer.dart';

/// Chat pane for the web two-pane layout. Online-only (no local DB): messages
/// are fetched from the API and kept live via the shared socket streams.
class WebChatView extends StatefulWidget {
  final Chat chat;
  const WebChatView({super.key, required this.chat});

  @override
  State<WebChatView> createState() => _WebChatViewState();
}

class _WebChatViewState extends State<WebChatView> {
  static const _quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _api = ApiService();
  final Map<String, GlobalKey> _messageKeys = {};

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _nextCursor;
  bool _showSend = false;
  bool _showEmoji = false;
  bool _isOnline = false;
  bool _isOtherTyping = false;
  Message? _replyingTo;
  String? _highlightedId;
  String? _hoveredId;
  final Set<String> _selectedIds = {};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecordingVoice = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  Timer? _typingClearTimer;
  Timer? _typingDebounce;
  Timer? _highlightTimer;
  bool _notifiedTyping = false;

  StreamSubscription<Message>? _messageSub;
  StreamSubscription<MessageStatusUpdate>? _statusSub;
  StreamSubscription<Map<String, dynamic>>? _typingSub;
  StreamSubscription<Map<String, dynamic>>? _editSub;
  StreamSubscription<Map<String, dynamic>>? _deleteSub;
  StreamSubscription<Map<String, dynamic>>? _reactionSub;
  StreamSubscription<Map<String, dynamic>>? _presenceSub;

  @override
  void initState() {
    super.initState();
    _isOnline = widget.chat.isOnline;
    _bind();
  }

  @override
  void didUpdateWidget(covariant WebChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat.id != widget.chat.id) {
      _isOnline = widget.chat.isOnline;
      _isOtherTyping = false;
      _replyingTo = null;
      _showEmoji = false;
      _selectedIds.clear();
      _hoveredId = null;
      _bind();
    }
  }

  void _bind() {
    final vm = context.read<WebChatViewModel>();
    vm.setActiveChat(widget.chat.id);
    SocketService().setActiveChatId(widget.chat.id);
    _loadMessages();
    _listenToSocket();
    _pollPresence();
  }

  Future<void> _pollPresence() async {
    final rid = widget.chat.receiverId;
    if (rid.isEmpty || rid.startsWith('new_')) return;
    try {
      final presence = await _api.getPresence(rid);
      if (mounted) setState(() => _isOnline = presence['is_online'] == true);
    } catch (_) {}
  }

  void _listenToSocket() {
    _cancelSubs();
    final socket = SocketService();
    _messageSub = socket.messageStream.listen((m) {
      if (m.chatId != widget.chat.id || !mounted) return;
      setState(() => _upsert(m));
      if (!m.isMe) {
        context.read<WebChatViewModel>().markChatRead(widget.chat.id);
      }
    });
    _statusSub = socket.messageStatusStream.listen((s) {
      if (s.chatId != widget.chat.id || !mounted) return;
      final ids = s.messageIds.isEmpty ? [s.messageId] : s.messageIds;
      setState(() {
        for (final id in ids) {
          final i = _messages.indexWhere((m) => m.id == id);
          if (i != -1) {
            _messages[i] = _messages[i].copyWith(deliveryState: s.deliveryState);
          }
        }
      });
    });
    _typingSub = socket.typingStream.listen((data) {
      if (data['chat_id']?.toString() != widget.chat.id) return;
      if (data['user_id']?.toString() == ApiService.currentUserId) return;
      final isTyping = data['is_typing'] == true;
      if (!mounted || _isOtherTyping == isTyping) return;
      setState(() => _isOtherTyping = isTyping);
      _typingClearTimer?.cancel();
      if (isTyping) {
        _typingClearTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _isOtherTyping = false);
        });
      }
    });
    _editSub = socket.messageEditStream.listen((data) {
      if (data['chat_id']?.toString() != widget.chat.id || !mounted) return;
      final i = _messages.indexWhere(
        (m) => m.id == data['message_id']?.toString(),
      );
      if (i == -1) return;
      setState(() {
        _messages[i] = _messages[i].copyWith(
          text: data['new_content']?.toString() ?? _messages[i].text,
          editedAt: DateTime.now(),
        );
      });
    });
    _deleteSub = socket.messageDeleteStream.listen((data) {
      if (data['chat_id']?.toString() != widget.chat.id || !mounted) return;
      final i = _messages.indexWhere(
        (m) => m.id == data['message_id']?.toString(),
      );
      if (i == -1) return;
      setState(() {
        _messages[i] = _messages[i].copyWith(
          text: '',
          isDeletedForEveryone: true,
          fileUrl: '',
        );
      });
    });
    _reactionSub = socket.reactionStream.listen((data) {
      if (data['chat_id']?.toString() != widget.chat.id || !mounted) return;
      _applyReaction(data);
    });
    _presenceSub = socket.presenceStream.listen((data) {
      if (data['user_id']?.toString() == widget.chat.receiverId && mounted) {
        setState(() => _isOnline = data['is_online'] == true);
      }
    });
  }

  void _applyReaction(Map<String, dynamic> data) {
    final i = _messages.indexWhere(
      (m) => m.id == data['message_id']?.toString(),
    );
    if (i == -1) return;
    final emoji = data['emoji']?.toString();
    final userId = data['user_id']?.toString();
    if (emoji == null || userId == null) return;
    final reactions = Map<String, List<String>>.from(
      _messages[i].reactions.map((k, v) => MapEntry(k, List<String>.from(v))),
    );
    if (data['action'] == 'remove') {
      reactions[emoji]?.remove(userId);
      if (reactions[emoji]?.isEmpty ?? false) reactions.remove(emoji);
    } else {
      reactions.putIfAbsent(emoji, () => []);
      if (!reactions[emoji]!.contains(userId)) reactions[emoji]!.add(userId);
    }
    setState(() => _messages[i] = _messages[i].copyWith(reactions: reactions));
  }

  void _upsert(Message message) {
    final i = _messages.indexWhere(
      (m) => m.id == message.id || m.clientUuid == message.clientUuid,
    );
    if (i == -1) {
      _messages.insert(0, message);
    } else {
      _messages[i] = message;
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final page = await _api.getMessagesPage(widget.chat.id);
      if (!mounted) return;
      setState(() {
        _messages = page.items;
        _nextCursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
        _isLoading = false;
      });
      context.read<WebChatViewModel>().markChatRead(widget.chat.id);
    } catch (e) {
      debugPrint('web loadMessages failed: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _nextCursor == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final page = await _api.getMessagesPage(
        widget.chat.id,
        cursor: _nextCursor,
      );
      if (!mounted) return;
      setState(() {
        final ids = _messages.map((m) => m.id).toSet();
        _messages.addAll(page.items.where((m) => !ids.contains(m.id)));
        _nextCursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
      });
    } catch (e) {
      debugPrint('web loadMore failed: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) _loadMore();
  }

  void _onChanged(String value) {
    final show = value.trim().isNotEmpty;
    if (show != _showSend) setState(() => _showSend = show);
    _notifyTyping();
  }

  void _notifyTyping() {
    final id = widget.chat.id;
    if (id.startsWith('new_')) return;
    if (!_notifiedTyping) {
      _notifiedTyping = true;
      _api.sendTyping(id, true).catchError((_) {});
    }
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 3), () {
      _notifiedTyping = false;
      _api.sendTyping(id, false).catchError((_) {});
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final clientUuid = ApiService.createClientUuid();
    final replyId = _replyingTo?.id;
    _controller.clear();
    setState(() {
      _showSend = false;
      _replyingTo = null;
      _messages.insert(
        0,
        Message(
          id: clientUuid,
          clientUuid: clientUuid,
          text: text,
          senderId: ApiService.currentUserId ?? '0',
          time: DateTime.now(),
          isMe: true,
          chatId: widget.chat.id,
          deliveryState: DeliveryState.pending,
          replyToId: replyId,
        ),
      );
    });
    try {
      final message = await _api.sendMessage(
        widget.chat.receiverId,
        text,
        clientUuid: clientUuid,
        replyTo: replyId,
      );
      if (mounted) setState(() => _upsert(message));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final i = _messages.indexWhere((m) => m.clientUuid == clientUuid);
        if (i != -1) {
          _messages[i] = _messages[i].copyWith(
            deliveryState: DeliveryState.failed,
          );
        }
      });
    }
  }

  // ── attachments ───────────────────────────────────────────────

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo, color: Colors.purple),
              title: const Text('Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.orange),
              title: const Text('Video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: Colors.indigo),
              title: const Text('Document'),
              onTap: () {
                Navigator.pop(context);
                _pickDocument();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
    );
    if (picked != null) _sendAttachment(picked, 'image');
  }

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked != null) _sendAttachment(picked, 'video');
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    _sendAttachment(
      XFile.fromData(bytes, name: f.name, mimeType: 'application/octet-stream'),
      'document',
      fileName: f.name,
    );
  }

  // ── voice recording (WhatsApp-Web style) ─────────────────────

  Future<void> _startVoiceRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Microphone permission needed — allow it in the browser',
              ),
            ),
          );
        }
        return;
      }
      // Browsers record opus (webm container); AAC isn't available on web.
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.opus, bitRate: 128000),
        path: '',
      );
      if (!mounted) return;
      setState(() {
        _isRecordingVoice = true;
        _recordSeconds = 0;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
    } catch (e) {
      debugPrint('web voice record start failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start recording')),
        );
      }
    }
  }

  Future<void> _cancelVoiceRecording() async {
    _recordTimer?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {}
    if (mounted) setState(() => _isRecordingVoice = false);
  }

  Future<void> _stopAndSendVoice() async {
    _recordTimer?.cancel();
    final seconds = _recordSeconds;
    String? blobUrl;
    try {
      blobUrl = await _recorder.stop();
    } catch (e) {
      debugPrint('web voice record stop failed: $e');
    }
    if (mounted) setState(() => _isRecordingVoice = false);
    if (blobUrl == null || blobUrl.isEmpty || seconds < 1) return;
    await _sendAttachment(
      XFile(blobUrl),
      'audio',
      fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.webm',
      duration: seconds.toDouble(),
    );
  }

  String _formatRecordTime(int seconds) {
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _sendAttachment(
    XFile file,
    String type, {
    String? fileName,
    double? duration,
  }) async {
    final clientUuid = ApiService.createClientUuid();
    final replyId = _replyingTo?.id;
    final placeholder = switch (type) {
      'image' => '📷 Photo',
      'video' => '🎬 Video',
      'audio' => '🎤 Voice message',
      _ => '📎 File',
    };
    setState(() {
      _replyingTo = null;
      _messages.insert(
        0,
        Message(
          id: clientUuid,
          clientUuid: clientUuid,
          text: placeholder,
          senderId: ApiService.currentUserId ?? '0',
          time: DateTime.now(),
          isMe: true,
          chatId: widget.chat.id,
          type: type,
          fileName: fileName,
          deliveryState: DeliveryState.pending,
          replyToId: replyId,
        ),
      );
    });
    try {
      final message = await _api.sendMessage(
        widget.chat.receiverId,
        '[File]',
        clientUuid: clientUuid,
        file: file,
        fileName: fileName ?? file.name,
        type: type,
        replyTo: replyId,
        duration: duration,
      );
      if (mounted) setState(() => _upsert(message));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final i = _messages.indexWhere((m) => m.clientUuid == clientUuid);
        if (i != -1) {
          _messages[i] = _messages[i].copyWith(
            deliveryState: DeliveryState.failed,
          );
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to send file')));
    }
  }

  // ── message actions ───────────────────────────────────────────

  void _showMessageMenu(Message message, Offset position) {
    if (message.isDeletedForEveryone) return;
    final canEdit =
        message.isMe &&
        message.type == 'text' &&
        DateTime.now().difference(message.time) < const Duration(minutes: 15);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          enabled: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final emoji in _quickReactions)
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _react(message, emoji);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                ),
            ],
          ),
        ),
        const PopupMenuItem(value: 'reply', child: Text('Reply')),
        if (message.text.isNotEmpty && message.text != '[File]')
          const PopupMenuItem(value: 'copy', child: Text('Copy')),
        if (canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit')),
        const PopupMenuItem(value: 'forward', child: Text('Forward')),
        const PopupMenuItem(value: 'select', child: Text('Select messages')),
        const PopupMenuItem(value: 'delete_me', child: Text('Delete for me')),
        if (message.isMe)
          const PopupMenuItem(
            value: 'delete_all',
            child: Text('Delete for everyone'),
          ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'reply':
          setState(() => _replyingTo = message);
        case 'copy':
          Clipboard.setData(ClipboardData(text: message.text));
        case 'edit':
          _editDialog(message);
        case 'forward':
          _forward(message);
        case 'select':
          setState(() => _selectedIds.add(message.id));
        case 'delete_me':
          _delete(message, 'for_me');
        case 'delete_all':
          _delete(message, 'for_everyone');
      }
    });
  }

  // ── multi-select ──────────────────────────────────────────────

  void _toggleSelection(Message message) {
    setState(() {
      if (!_selectedIds.remove(message.id)) {
        _selectedIds.add(message.id);
      }
    });
  }

  void _exitSelection() => setState(_selectedIds.clear);

  List<Message> get _selectedMessages {
    // Oldest first so a bulk forward arrives in the original order.
    final selected =
        _messages.where((m) => _selectedIds.contains(m.id)).toList();
    return selected.reversed.toList();
  }

  void _bulkForward() {
    final selected = _selectedMessages;
    if (selected.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ForwardContactPickerSheet(
        message: selected.first,
        onContactsSelected: (chatIds) async {
          Navigator.pop(context);
          _exitSelection();
          for (final message in selected) {
            for (final chatId in chatIds) {
              await _api.forwardMessage(
                originalMessageId: message.id,
                toChatId: chatId,
              );
            }
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                chatIds.length == 1
                    ? 'Forwarded ${selected.length} message${selected.length == 1 ? '' : 's'}'
                    : 'Forwarded to ${chatIds.length} chats',
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _bulkDelete() async {
    final selected = _selectedMessages;
    if (selected.isEmpty) return;
    final allMine = selected.every((m) => m.isMe);
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${selected.length} message${selected.length == 1 ? '' : 's'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'for_me'),
            child: const Text('Delete for me'),
          ),
          if (allMine)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'for_everyone'),
              child: const Text(
                'Delete for everyone',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
    if (choice == null) return;
    _exitSelection();
    for (final message in selected) {
      await _delete(message, choice);
    }
  }

  Future<void> _react(Message message, String emoji) async {
    try {
      await _api.reactToMessage(message.id, emoji);
    } catch (_) {}
  }

  Future<void> _editDialog(Message message) async {
    final controller = TextEditingController(text: message.text);
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(controller: controller, autofocus: true, maxLines: 4),
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
      await _api.editMessage(message.id, newText);
      if (!mounted) return;
      setState(() {
        final i = _messages.indexWhere((m) => m.id == message.id);
        if (i != -1) {
          _messages[i] = _messages[i].copyWith(
            text: newText,
            editedAt: DateTime.now(),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _delete(Message message, String deleteType) async {
    final isPending = int.tryParse(message.id) == null;
    try {
      if (!isPending) await _api.deleteMessage(message.id, deleteType);
      if (!mounted) return;
      setState(() {
        final i = _messages.indexWhere((m) => m.id == message.id);
        if (i == -1) return;
        if (deleteType == 'for_me' || isPending) {
          _messages.removeAt(i);
        } else {
          _messages[i] = _messages[i].copyWith(
            text: '',
            isDeletedForEveryone: true,
            fileUrl: '',
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _forward(Message message) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ForwardContactPickerSheet(
        message: message,
        onContactsSelected: (chatIds) async {
          Navigator.pop(context);
          for (final chatId in chatIds) {
            await _api.forwardMessage(
              originalMessageId: message.id,
              toChatId: chatId,
            );
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                chatIds.length == 1
                    ? 'Forwarded'
                    : 'Forwarded to ${chatIds.length} chats',
              ),
            ),
          );
        },
      ),
    );
  }

  void _scrollToReply(String? messageId) {
    if (messageId == null) return;
    final key = _messageKeys[messageId];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 280),
        alignment: 0.4,
      );
    }
    _highlightTimer?.cancel();
    setState(() => _highlightedId = messageId);
    _highlightTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _highlightedId = null);
    });
  }

  void _cancelSubs() {
    _messageSub?.cancel();
    _statusSub?.cancel();
    _typingSub?.cancel();
    _editSub?.cancel();
    _deleteSub?.cancel();
    _reactionSub?.cancel();
    _presenceSub?.cancel();
  }

  @override
  void dispose() {
    _cancelSubs();
    _typingClearTimer?.cancel();
    _typingDebounce?.cancel();
    _highlightTimer?.cancel();
    _recordTimer?.cancel();
    _recorder.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _isSelectionMode ? _selectionBar() : _header(),
        Expanded(
          child: Container(
            color: AppColors.chatBackgroundColor,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : NotificationListener<ScrollNotification>(
                    onNotification: (_) {
                      _onScroll();
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 16,
                      ),
                      itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _messages.length) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return _bubble(_messages[index]);
                      },
                    ),
                  ),
          ),
        ),
        if (_replyingTo != null) _replyPreview(),
        _composer(),
        if (_showEmoji)
          SizedBox(height: 280, child: _emojiPicker()),
      ],
    );
  }

  Widget _selectionBar() {
    return Container(
      height: 60,
      color: AppColors.primaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Cancel',
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _exitSelection,
          ),
          Text(
            '${_selectedIds.length} selected',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Forward',
            icon: const Icon(Icons.forward, color: Colors.white),
            onPressed: _bulkForward,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _bulkDelete,
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      height: 60,
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey[300],
            backgroundImage: widget.chat.avatarUrl.isNotEmpty
                ? CachedNetworkImageProvider(
                    ApiService.mediaUrl(widget.chat.avatarUrl),
                  )
                : null,
            child: widget.chat.avatarUrl.isEmpty
                ? const Icon(Icons.person, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.chat.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              Text(
                _isOtherTyping
                    ? 'typing…'
                    : (_isOnline ? 'online' : 'offline'),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bubble(Message message) {
    final isMe = message.isMe;
    final key = _messageKeys.putIfAbsent(message.id, GlobalKey.new);
    final highlighted = message.id == _highlightedId;

    Widget content;
    if (message.isDeletedForEveryone) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.block, size: 15, color: Colors.grey),
          const SizedBox(width: 6),
          Text(
            'This message was deleted',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey[600],
            ),
          ),
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.isForwarded)
            Row(
              children: [
                Icon(Icons.shortcut, size: 13, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'Forwarded',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          if (message.replyToId != null) _replyBanner(message),
          if (message.type != 'text') _media(message),
          if (message.text.isNotEmpty && !_isPlaceholder(message.text))
            Text(message.text, style: const TextStyle(fontSize: 15)),
          if (message.reactions.isNotEmpty) _reactionChips(message),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.editedAt != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    'edited',
                    style: TextStyle(color: Colors.grey[600], fontSize: 10),
                  ),
                ),
              Text(
                DateFormat('hh:mm a').format(message.time.toLocal()),
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                _statusIcon(message.deliveryState),
              ],
            ],
          ),
        ],
      );
    }

    final selected = _selectedIds.contains(message.id);
    final hovered = _hoveredId == message.id;
    final showMenuButton =
        hovered && !_isSelectionMode && !message.isDeletedForEveryone;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredId = message.id),
      onExit: (_) {
        if (_hoveredId == message.id) setState(() => _hoveredId = null);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _isSelectionMode ? () => _toggleSelection(message) : null,
        onSecondaryTapDown: (d) =>
            _showMessageMenu(message, d.globalPosition),
        onLongPressStart: (d) => _showMessageMenu(message, d.globalPosition),
        child: Container(
          key: key,
          padding: const EdgeInsets.symmetric(vertical: 3),
          color: selected
              ? AppColors.primaryColor.withValues(alpha: 0.12)
              : Colors.transparent,
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (_isSelectionMode) ...[
                Icon(
                  selected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected ? AppColors.primaryColor : Colors.grey,
                ),
                const SizedBox(width: 8),
              ],
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.4,
                    ),
                    decoration: BoxDecoration(
                      color: highlighted
                          ? const Color(0xFFFFF3B0)
                          : (isMe
                                ? AppColors.outgoingMessageColor
                                : Colors.white),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 1,
                        ),
                      ],
                    ),
                    // In selection mode the whole bubble is one tap target, so
                    // suppress inner taps (media viewer, links, reply-jump).
                    child: IgnorePointer(
                      ignoring: _isSelectionMode,
                      child: content,
                    ),
                  ),
                  // WhatsApp-Web-style hover chevron that opens the message
                  // menu (reply/forward/select/…) without a right-click.
                  if (showMenuButton)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTapDown: (d) =>
                            _showMessageMenu(message, d.globalPosition),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: (isMe
                                    ? AppColors.outgoingMessageColor
                                    : Colors.white)
                                .withValues(alpha: 0.95),
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(8),
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_down,
                            size: 20,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _replyBanner(Message message) {
    final authorIsMe = message.senderId == ApiService.currentUserId;
    final summary = _replySummary(message);
    return GestureDetector(
      onTap: () => _scrollToReply(message.replyToId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(5),
          border: const Border(
            left: BorderSide(color: AppColors.primaryColor, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              authorIsMe ? 'You' : widget.chat.name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryColor,
              ),
            ),
            Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  String _replySummary(Message message) {
    final text = (message.replyToText ?? '').trim();
    if (text.isNotEmpty && text != '[File]') return text;
    switch (message.replyToType) {
      case 'image':
        return '📷 Photo';
      case 'video':
        return '🎬 Video';
      case 'audio':
        return '🎤 Voice message';
      case 'document':
        return message.replyToFileName ?? '📎 Document';
      default:
        return 'Message';
    }
  }

  Widget _media(Message message) {
    final url = ApiService.mediaUrl(message.fileUrl);
    if (url.isEmpty) {
      // Pending upload placeholder.
      return const Padding(
        padding: EdgeInsets.only(bottom: 4),
        child: SizedBox(
          width: 240,
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    switch (message.type) {
      case 'image':
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: GestureDetector(
            onTap: () => WebMediaViewer.open(context, url: url, isVideo: false),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: url,
                width: 240,
                fit: BoxFit.cover,
                placeholder: (_, _) => const SizedBox(
                  width: 240,
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, _, _) => const Icon(Icons.broken_image),
              ),
            ),
          ),
        );
      case 'video':
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: GestureDetector(
            onTap: () => WebMediaViewer.open(context, url: url, isVideo: true),
            child: Container(
              width: 240,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
        );
      case 'audio':
        return _fileChip(Icons.mic, 'Voice message', url);
      default:
        return _fileChip(
          Icons.insert_drive_file,
          message.fileName ?? 'Document',
          url,
        );
    }
  }

  Widget _fileChip(IconData icon, String label, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.primaryColor),
              const SizedBox(width: 8),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reactionChips(Message message) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        children: message.reactions.entries.map((e) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              '${e.key} ${e.value.length}',
              style: const TextStyle(fontSize: 11),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _statusIcon(MessageStatus state) {
    final read = state == DeliveryState.read;
    final delivered = state == DeliveryState.delivered || read;
    if (state == DeliveryState.sending) {
      return Icon(Icons.access_time, size: 13, color: Colors.grey[500]);
    }
    if (state == DeliveryState.failed) {
      return const Icon(Icons.error_outline, size: 13, color: Colors.red);
    }
    return Icon(
      delivered ? Icons.done_all : Icons.done,
      size: 15,
      color: read ? Colors.blue : Colors.grey,
    );
  }

  Widget _replyPreview() {
    final message = _replyingTo!;
    final authorIsMe = message.senderId == ApiService.currentUserId;
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: const Border(
            left: BorderSide(color: AppColors.primaryColor, width: 3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authorIsMe ? 'You' : widget.chat.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  Text(
                    _composerReplySummary(message),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _replyingTo = null),
            ),
          ],
        ),
      ),
    );
  }

  String _composerReplySummary(Message message) {
    final text = message.text.trim();
    if (text.isNotEmpty && !_isPlaceholder(text) && text != '[File]') {
      return text;
    }
    switch (message.type) {
      case 'image':
        return '📷 Photo';
      case 'video':
        return '🎬 Video';
      case 'audio':
        return '🎤 Voice message';
      case 'document':
        return message.fileName ?? '📎 Document';
      default:
        return 'Message';
    }
  }

  Widget _composer() {
    if (_isRecordingVoice) return _recordingBar();
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined,
              color: Colors.grey[700],
            ),
            onPressed: () => setState(() => _showEmoji = !_showEmoji),
          ),
          IconButton(
            icon: Icon(Icons.attach_file, color: Colors.grey[700]),
            onPressed: _showAttachMenu,
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              onSubmitted: (_) => _send(),
              onTap: () {
                if (_showEmoji) setState(() => _showEmoji = false);
              },
              textInputAction: TextInputAction.send,
              minLines: 1,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Type a message',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: _showSend ? 'Send' : 'Record voice message',
            icon: Icon(
              _showSend ? Icons.send : Icons.mic,
              color: AppColors.primaryColor,
            ),
            onPressed: _showSend ? _send : _startVoiceRecording,
          ),
        ],
      ),
    );
  }

  /// WhatsApp-Web-style recording strip: trash to cancel, blinking red dot
  /// with elapsed time, and a send button to stop-and-send.
  Widget _recordingBar() {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Cancel',
            icon: Icon(Icons.delete_outline, color: Colors.grey[700]),
            onPressed: _cancelVoiceRecording,
          ),
          const Spacer(),
          _BlinkingDot(),
          const SizedBox(width: 8),
          Text(
            _formatRecordTime(_recordSeconds),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[800],
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Recording…',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const Spacer(),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.primaryColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              tooltip: 'Send voice message',
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _stopAndSendVoice,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emojiPicker() {
    return EmojiPicker(
      textEditingController: _controller,
      onEmojiSelected: (_, _) {
        if (!_showSend) setState(() => _showSend = true);
      },
      config: const Config(
        height: 280,
        checkPlatformCompatibility: true,
        emojiViewConfig: EmojiViewConfig(backgroundColor: Colors.white),
        categoryViewConfig: CategoryViewConfig(
          indicatorColor: AppColors.primaryColor,
          iconColorSelected: AppColors.primaryColor,
        ),
      ),
    );
  }

  bool _isPlaceholder(String text) {
    const placeholders = {
      '[File]',
      '📷 Photo',
      '🎬 Video',
      '📎 File',
      '🎤 Voice message',
    };
    return placeholders.contains(text.trim());
  }
}

/// Pulsing red dot shown while a voice message is being recorded.
class _BlinkingDot extends StatefulWidget {
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.25, end: 1).animate(_controller),
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
