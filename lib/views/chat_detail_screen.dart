import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../utils/constants.dart';
import '../viewmodels/chat_viewmodel.dart';

class ChatDetailScreen extends StatefulWidget {
  final Chat chat;

  const ChatDetailScreen({super.key, required this.chat});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _showSendIcon = false;
  List<Message> _messages = [];
  bool _isLoading = true;
  StreamSubscription<Message>? _socketSubscription;
  StreamSubscription<MessageStatusUpdate>? _messageStatusSubscription;
  String? _currentChatId;
  Set<String> _downloadedUrls = {};
  late final ChatViewModel _chatViewModel;
  
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _chatViewModel = context.read<ChatViewModel>();
    _currentChatId = widget.chat.id;
    _chatViewModel.setActiveChat(_currentChatId);
    _loadDownloadedFiles();
    _refreshMessages();
    _initSocket();
  }

  void _initSocket() {
    _socketSubscription = SocketService().messageStream.listen((message) {
      if (message.chatId == _currentChatId) {
        setState(() {
          _upsertMessage(message);
        });
      }
    });
    _messageStatusSubscription = SocketService().messageStatusStream.listen((status) {
      if (status.chatId == _currentChatId) {
        setState(() {
          _applyMessageStatus(status);
        });
      }
    });
  }

  void _loadMessages() async {
    if (_currentChatId == null || _currentChatId!.startsWith('new_')) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final messages = await _apiService.getMessages(_currentChatId!);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _chatViewModel.markChatRead(_currentChatId!);
    } catch (e) {
      debugPrint('Error loading messages: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDownloadedFiles() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _downloadedUrls = (prefs.getStringList('downloaded_urls') ?? []).toSet();
    });
  }

  Future<void> _markAsDownloaded(String url) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _downloadedUrls.add(url);
    });
    await prefs.setStringList('downloaded_urls', _downloadedUrls.toList());
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _messageStatusSubscription?.cancel();
    if (_chatViewModel.activeChatId == _currentChatId) {
      _chatViewModel.setActiveChat(null);
    }
    _audioRecorder.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _upsertMessage(Message message) {
    final existingIndex = _messages.indexWhere((item) => item.id == message.id);
    if (existingIndex == -1) {
      _messages.insert(0, message);
      return;
    }

    final currentMessage = _messages[existingIndex];
    _messages[existingIndex] = message.copyWith(
      isDelivered: currentMessage.isDelivered || message.isDelivered,
      isRead: currentMessage.isRead || message.isRead,
    );
  }

  void _applyMessageStatus(MessageStatusUpdate status) {
    final existingIndex = _messages.indexWhere((item) => item.id == status.messageId);
    if (existingIndex == -1) return;

    final currentMessage = _messages[existingIndex];
    _messages[existingIndex] = currentMessage.copyWith(
      isDelivered: currentMessage.isDelivered || status.isDelivered,
      isRead: currentMessage.isRead || status.isRead,
    );
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        _recordingPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        final config = RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        );
        await _audioRecorder.start(config, path: _recordingPath!);
        
        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
      if (path != null) {
        _sendFileMessage(File(path), 'audio');
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }


  void _refreshMessages() {
    _loadMessages();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      _messageController.clear();
      setState(() => _showSendIcon = false);
      
      final message = await _apiService.sendMessage(widget.chat.receiverId, text);
      if (message != null) {
        if (_currentChatId!.startsWith('new_')) {
          _currentChatId = message.chatId;
          _chatViewModel.setActiveChat(_currentChatId);
        }
        setState(() {
          _upsertMessage(message);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to send message")),
          );
        }
      }
    }
  }

  void _sendFileMessage(File file, [String? type]) async {
    final message = await _apiService.sendMessage(widget.chat.receiverId, "[File]", file: file, type: type);
    if (message != null) {
      if (_currentChatId!.startsWith('new_')) {
        _currentChatId = message.chatId;
        _chatViewModel.setActiveChat(_currentChatId);
      }
      setState(() {
        _upsertMessage(message);
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send file')),
        );
      }
    }
  }

  void _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      _sendFileMessage(File(pickedFile.path));
    }
  }

  void _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
    );

    if (result != null && result.files.single.path != null) {
      _sendFileMessage(File(result.files.single.path!));
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (builder) => SizedBox(
        height: 280,
        width: MediaQuery.of(context).size.width,
        child: Card(
          margin: const EdgeInsets.all(18.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _iconCreation(Icons.insert_drive_file, Colors.indigo, "Document", _pickFile),
                    const SizedBox(width: 40),
                    _iconCreation(Icons.camera_alt, Colors.pink, "Camera", () => _pickImage(ImageSource.camera)),
                    const SizedBox(width: 40),
                    _iconCreation(Icons.insert_photo, Colors.purple, "Gallery", () => _pickImage(ImageSource.gallery)),
                  ],
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _iconCreation(Icons.headset, Colors.orange, "Audio", () {}),
                    const SizedBox(width: 40),
                    _iconCreation(Icons.location_pin, Colors.teal, "Location", () {}),
                    const SizedBox(width: 40),
                    _iconCreation(Icons.person, Colors.blue, "Contact", () {}),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconCreation(IconData icon, Color color, String text, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: color,
            child: Icon(icon, size: 29, color: Colors.white),
          ),
          const SizedBox(height: 5),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file')),
        );
      }
    }
  }

  Future<void> _downloadAndSaveImage(String url) async {
    try {
      // Request permissions
      if (Platform.isAndroid) {
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          await Gal.requestAccess();
        }
      }

      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await Dio().download(url, path);
      await Gal.putImage(path);
      await _markAsDownloaded(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image saved to gallery')),
        );
      }
      
      // Clean up temp file
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey[300],
              backgroundImage: widget.chat.avatarUrl.isNotEmpty 
                  ? NetworkImage(widget.chat.avatarUrl) 
                  : null,
              child: widget.chat.avatarUrl.isEmpty 
                  ? Icon(Icons.person, color: Colors.grey[600]) 
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.chat.name, 
                style: const TextStyle(color: Colors.white, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam), onPressed: () {}),
          IconButton(icon: const Icon(Icons.call), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.chatBackgroundColor,
                image: DecorationImage(
                  image: const NetworkImage("https://user-images.githubusercontent.com/15075759/28719144-86dc0f70-73b1-11e7-911d-60d70fcded21.png"),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    AppColors.chatBackgroundColor.withValues(alpha: 0.8), 
                    BlendMode.dstATop,
                  ),
                ),
              ),
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty 
                  ? Container(
                      color: AppColors.chatBackgroundColor,
                      width: double.infinity,
                      height: double.infinity,
                      child: Center(
                        child: Text(
                          "No messages yet",
                          style: TextStyle(color: Colors.grey[800]),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: _messages.length,
                      reverse: true,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return _buildMessage(message);
                      },
                    ),
            ),
          ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildMessage(Message message) {
    bool isMe = message.isMe;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppColors.outgoingMessageColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.fileUrl != null && message.fileUrl!.isNotEmpty) ...[
              if (message.fileUrl!.toLowerCase().endsWith('.jpg') || 
                  message.fileUrl!.toLowerCase().endsWith('.jpeg') || 
                  message.fileUrl!.toLowerCase().endsWith('.png') ||
                  message.fileUrl!.toLowerCase().endsWith('.gif'))
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        message.fileUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50),
                      ),
                    ),
                    if (!_downloadedUrls.contains(message.fileUrl!))
                      Positioned(
                        right: 5,
                        bottom: 5,
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.download, size: 18, color: Colors.white),
                            onPressed: () => _downloadAndSaveImage(message.fileUrl!),
                          ),
                        ),
                      ),
                  ],
                )
              else if (message.fileUrl!.toLowerCase().endsWith('.m4a') || 
                       message.fileUrl!.toLowerCase().endsWith('.mp3'))
                AudioPlayerWidget(url: message.fileUrl!)
              else
                InkWell(
                  onTap: () => _openFile(message.fileUrl!),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.insert_drive_file, color: AppColors.primaryColor),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message.fileUrl!.split('/').last,
                          style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 5),
            ],
            if (message.text != "[File]") 
              Text(
                message.text,
                style: const TextStyle(color: Colors.black, fontSize: 16),
              ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('hh:mm a').format(message.time.toLocal()),
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : (message.isDelivered ? Icons.done_all : Icons.done),
                    size: 14,
                    color: message.isRead ? Colors.blue : Colors.grey,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: _isRecording 
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Text("Recording... (Release to send)", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        )
                      : TextField(
                          controller: _messageController,
                          onChanged: (val) {
                            setState(() {
                              _showSendIcon = val.trim().isNotEmpty;
                            });
                          },
                          decoration: const InputDecoration(
                            hintText: "Type a message",
                            border: InputBorder.none,
                          ),
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.grey),
                    onPressed: _showAttachmentOptions,
                  ),
                  if (!_showSendIcon)
                    IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.grey),
                      onPressed: () => _pickImage(ImageSource.camera),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onLongPress: _startRecording,
            onLongPressEnd: (_) => _stopRecording(),
            child: FloatingActionButton(
              onPressed: _showSendIcon ? _sendMessage : null,
              backgroundColor: AppColors.primaryColor,
              mini: true,
              child: Icon(
                _showSendIcon ? Icons.send : Icons.mic,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AudioPlayerWidget extends StatefulWidget {
  final String url;
  const AudioPlayerWidget({super.key, required this.url});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    debugPrint("DEBUG: AudioPlayerWidget loading URL: ${widget.url}");
    _player.setSource(UrlSource(widget.url)).catchError((e) {
      debugPrint("DEBUG: Failed to set audio source: $e");
    }).then((_) {
      _player.getDuration().then((d) {
        if (d != null) setState(() => _duration = d);
      });
    });
    _player.onDurationChanged.listen((d) => setState(() => _duration = d));
    _player.onPositionChanged.listen((p) => setState(() => _position = p));
    _player.onPlayerComplete.listen((_) => setState(() {
      _isPlaying = false;
      _position = Duration.zero;
    }));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: AppColors.primaryColor),
            onPressed: () async {
              try {
                if (_isPlaying) {
                  await _player.pause();
                } else {
                  await _player.resume();
                }
                setState(() => _isPlaying = !_isPlaying);
              } catch (e) {
                debugPrint("Error playing audio: $e");
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error playing audio: $e')),
                  );
                }
              }
            },
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 5),
              Text(
                "${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')} / ${_duration.inMinutes}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 5),
            ],
          ),
        ],
      ),
    );
  }
}
