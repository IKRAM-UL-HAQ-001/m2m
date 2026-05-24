import 'package:flutter/material.dart';

import '../../../models/message.dart';
import '../../../utils/constants.dart';

class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    super.key,
    required this.messageController,
    required this.focusNode,
    required this.showEmojiPicker,
    required this.showSendIcon,
    required this.isRecording,
    required this.isLocked,
    required this.isCancelling,
    required this.recordingDuration,
    required this.recordingCurrentOffset,
    required this.blinkAnimation,
    required this.pulseAnimation,
    required this.replyingToMessage,
    required this.replyAuthorName,
    required this.replySummaryBuilder,
    required this.replyMediaThumbBuilder,
    required this.onTextChanged,
    required this.onToggleEmojiPicker,
    required this.onShowAttachmentOptions,
    required this.onOpenCamera,
    required this.onCancelReply,
    required this.onSendMessage,
    required this.onStartRecordingPointerDown,
    required this.onRecordingPointerMove,
    required this.onRecordingPointerUp,
    required this.onCancelLockedRecording,
    required this.onStopRecording,
  });

  final TextEditingController messageController;
  final FocusNode focusNode;
  final bool showEmojiPicker;
  final bool showSendIcon;
  final bool isRecording;
  final bool isLocked;
  final bool isCancelling;
  final Duration recordingDuration;
  final ValueNotifier<Offset> recordingCurrentOffset;
  final Animation<double> blinkAnimation;
  final Animation<double> pulseAnimation;
  final Message? replyingToMessage;
  final String replyAuthorName;
  final String Function(Message message) replySummaryBuilder;
  final Widget Function(Message message) replyMediaThumbBuilder;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onToggleEmojiPicker;
  final VoidCallback onShowAttachmentOptions;
  final VoidCallback onOpenCamera;
  final VoidCallback onCancelReply;
  final VoidCallback onSendMessage;
  final ValueChanged<PointerDownEvent> onStartRecordingPointerDown;
  final ValueChanged<PointerMoveEvent> onRecordingPointerMove;
  final ValueChanged<PointerUpEvent> onRecordingPointerUp;
  final VoidCallback onCancelLockedRecording;
  final VoidCallback onStopRecording;

  @override
  Widget build(BuildContext context) {
    if (isLocked) {
      return SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: true,
        child: _buildLockedRecordingUI(),
      );
    }
    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      child: Container(
        color: const Color(0xFFF0F0F0),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyingToMessage != null) _buildReplyPreview(),
            _buildInputRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    final msg = replyingToMessage!;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: AppColors.primaryColor, width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg.isMe ? 'You' : replyAuthorName,
                  style: const TextStyle(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  replySummaryBuilder(msg),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (msg.fileUrl != null && msg.fileUrl!.isNotEmpty) ...[
            const SizedBox(width: 8),
            replyMediaThumbBuilder(msg),
          ],
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onCancelReply,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isRecording)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: IconButton(
                      icon: Icon(
                        showEmojiPicker
                            ? Icons.keyboard_alt_outlined
                            : Icons.emoji_emotions_outlined,
                        color: Colors.grey[600],
                      ),
                      onPressed: onToggleEmojiPicker,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ),
                Expanded(
                  child: isRecording
                      ? _RecordingStatus(
                          blinkAnimation: blinkAnimation,
                          durationText: _formatRecordingTime(recordingDuration),
                          isCancelling: isCancelling,
                        )
                      : TextField(
                          controller: messageController,
                          focusNode: focusNode,
                          minLines: 1,
                          maxLines: 6,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: onTextChanged,
                          decoration: const InputDecoration(
                            hintText: 'Message',
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                ),
                if (!isRecording) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: IconButton(
                      icon: Icon(Icons.attach_file, color: Colors.grey[600]),
                      onPressed: onShowAttachmentOptions,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ),
                  if (!showSendIcon)
                    Padding(
                      padding: const EdgeInsets.only(right: 4, bottom: 4),
                      child: IconButton(
                        icon: Icon(Icons.camera_alt, color: Colors.grey[600]),
                        onPressed: onOpenCamera,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [_buildLockIndicatorAbove(), _buildMicSendButton()],
        ),
      ],
    );
  }

  Widget _buildLockIndicatorAbove() {
    if (!isRecording || isLocked) return const SizedBox.shrink();
    return ValueListenableBuilder<Offset>(
      valueListenable: recordingCurrentOffset,
      builder: (context, offset, _) {
        final lockProgress = (-offset.dy / 120.0).clamp(0.0, 1.0);
        if (lockProgress <= 0.01) return const SizedBox.shrink();
        return Opacity(
          opacity: lockProgress,
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Icon(
              lockProgress > 0.75 ? Icons.lock : Icons.lock_open,
              color: lockProgress > 0.75 ? AppColors.primaryColor : Colors.grey,
              size: 18,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMicSendButton() {
    return Listener(
      onPointerDown: (event) {
        if (showSendIcon || isRecording) return;
        onStartRecordingPointerDown(event);
      },
      onPointerMove: (event) {
        if (!isRecording || isLocked) return;
        onRecordingPointerMove(event);
      },
      onPointerUp: (event) {
        if (!isRecording || isLocked) return;
        onRecordingPointerUp(event);
      },
      child: GestureDetector(
        onTap: showSendIcon ? onSendMessage : null,
        child: isRecording
            ? AnimatedBuilder(
                animation: pulseAnimation,
                builder: (context, child) => Transform.scale(
                  scale: pulseAnimation.value,
                  child: const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.red,
                    child: Icon(Icons.mic, color: Colors.white, size: 22),
                  ),
                ),
              )
            : CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryColor,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    showSendIcon ? Icons.send : Icons.mic,
                    key: ValueKey(showSendIcon),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildLockedRecordingUI() {
    return Container(
      color: const Color(0xFFF0F0F0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onCancelLockedRecording,
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 28),
          ),
          const SizedBox(width: 4),
          AnimatedBuilder(
            animation: blinkAnimation,
            builder: (context, _) => Opacity(
              opacity: blinkAnimation.value,
              child: const Icon(
                Icons.fiber_manual_record,
                color: Colors.red,
                size: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatRecordingTime(recordingDuration),
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onStopRecording,
            child: const CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFF4CAF50),
              child: Icon(Icons.send, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  String _formatRecordingTime(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _RecordingStatus extends StatelessWidget {
  const _RecordingStatus({
    required this.blinkAnimation,
    required this.durationText,
    required this.isCancelling,
  });

  final Animation<double> blinkAnimation;
  final String durationText;
  final bool isCancelling;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: blinkAnimation,
            builder: (context, _) => Opacity(
              opacity: blinkAnimation.value,
              child: const Icon(
                Icons.fiber_manual_record,
                color: Colors.red,
                size: 14,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            durationText,
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isCancelling ? 'Release to cancel' : '< Slide to cancel',
              style: TextStyle(
                color: isCancelling ? Colors.red : Colors.grey,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
