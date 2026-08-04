package com.danish.m2m

import android.content.Context
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.amazonaws.services.chime.sdk.meetings.audiovideo.AudioVideoFacade
import com.amazonaws.services.chime.sdk.meetings.audiovideo.AudioVideoObserver
import com.amazonaws.services.chime.sdk.meetings.audiovideo.SignalUpdate
import com.amazonaws.services.chime.sdk.meetings.audiovideo.VolumeUpdate
import com.amazonaws.services.chime.sdk.meetings.audiovideo.video.VideoTileObserver
import com.amazonaws.services.chime.sdk.meetings.audiovideo.video.VideoTileState
import com.amazonaws.services.chime.sdk.meetings.device.MediaDevice
import com.amazonaws.services.chime.sdk.meetings.device.MediaDeviceType
import com.amazonaws.services.chime.sdk.meetings.audiovideo.video.RemoteVideoSource
import com.amazonaws.services.chime.sdk.meetings.audiovideo.video.VideoPriority
import com.amazonaws.services.chime.sdk.meetings.audiovideo.video.VideoResolution
import com.amazonaws.services.chime.sdk.meetings.audiovideo.video.VideoSubscriptionConfiguration
import com.amazonaws.services.chime.sdk.meetings.audiovideo.AttendeeInfo
import com.amazonaws.services.chime.sdk.meetings.realtime.RealtimeObserver
import com.amazonaws.services.chime.sdk.meetings.session.Attendee
import com.amazonaws.services.chime.sdk.meetings.session.CreateAttendeeResponse
import com.amazonaws.services.chime.sdk.meetings.session.CreateMeetingResponse
import com.amazonaws.services.chime.sdk.meetings.session.DefaultMeetingSession
import com.amazonaws.services.chime.sdk.meetings.session.Meeting
import com.amazonaws.services.chime.sdk.meetings.session.MeetingSession
import com.amazonaws.services.chime.sdk.meetings.session.MeetingSessionConfiguration
import com.amazonaws.services.chime.sdk.meetings.session.MeetingSessionStatus
import com.amazonaws.services.chime.sdk.meetings.session.MediaPlacement
import com.amazonaws.services.chime.sdk.meetings.utils.logger.ConsoleLogger
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class ChimeMeetingPlugin(private val context: Context) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    AudioVideoObserver,
    VideoTileObserver,
    RealtimeObserver {

    private var meetingSession: MeetingSession? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val audioResetRunnable = Runnable { resetAndroidAudioAfterCall() }

    private var localTileId: Int? = null
    private var remoteTileId: Int? = null

    private var activeLocalView: ChimeVideoPlatformView? = null
    private var activeRemoteView: ChimeVideoPlatformView? = null

    private var localAttendeeId: String? = null
    private var desiredMuted: Boolean = false

    companion object {
        private const val TAG = "M2MChimeMeeting"
        private const val AUDIO_RESET_DELAY_MS = 500L

        fun registerWith(flutterEngine: FlutterEngine, context: Context) {
            val plugin = ChimeMeetingPlugin(context)

            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.danish.m2m/chime")
                .setMethodCallHandler(plugin)

            EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.danish.m2m/chime_events")
                .setStreamHandler(plugin)

            flutterEngine.platformViewsController.registry.registerViewFactory(
                "com.danish.m2m/chime_video",
                ChimeVideoPlatformViewFactory(plugin)
            )
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "join" -> {
                val meetingMap = call.argument<Map<String, Any>>("meeting")
                val attendeeMap = call.argument<Map<String, Any>>("attendee")
                val videoEnabled = call.argument<Boolean>("videoEnabled") ?: false

                if (meetingMap == null || attendeeMap == null) {
                    result.error("invalid_arguments", "Meeting or Attendee map was null", null)
                    return
                }

                try {
                    joinMeeting(meetingMap, attendeeMap, videoEnabled)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("join_failed", e.message, null)
                }
            }
            "leave" -> {
                leaveMeeting()
                result.success(null)
            }
            "setMuted" -> {
                val muted = call.argument<Boolean>("muted") ?: false
                val audioVideo = meetingSession?.audioVideo
                if (audioVideo == null) {
                    result.error("no_active_meeting", "No active meeting audio session.", null)
                    return
                }
                desiredMuted = muted
                applyLocalMute(audioVideo, muted)
                result.success(null)
            }
            "setCameraEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                if (enabled) {
                    meetingSession?.audioVideo?.startLocalVideo()
                } else {
                    meetingSession?.audioVideo?.stopLocalVideo()
                }
                result.success(null)
            }
            "switchCamera" -> {
                meetingSession?.audioVideo?.switchCamera()
                applyLocalMirror()
                result.success(null)
            }
            "setSpeakerEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                setSpeaker(enabled)
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun joinMeeting(meetingMap: Map<String, Any>, attendeeMap: Map<String, Any>, videoEnabled: Boolean) {
        leaveMeeting(resetAudio = false)

        val meetingId = meetingMap["MeetingId"] as? String ?: throw IllegalArgumentException("Missing MeetingId")
        val externalMeetingId = meetingMap["ExternalMeetingId"] as? String ?: ""
        val mediaPlacementMap = meetingMap["MediaPlacement"] as? Map<*, *> ?: throw IllegalArgumentException("Missing MediaPlacement")

        val audioHostUrl = mediaPlacementMap["AudioHostUrl"] as? String ?: ""
        val audioFallbackUrl = mediaPlacementMap["AudioFallbackUrl"] as? String ?: ""
        val signalingUrl = mediaPlacementMap["SignalingUrl"] as? String ?: ""
        val turnControlUrl = mediaPlacementMap["TurnControlUrl"] as? String ?: ""
        val eventIngestionUrl = mediaPlacementMap["EventIngestionUrl"] as? String

        val mediaPlacement = MediaPlacement(
            AudioFallbackUrl = audioFallbackUrl,
            AudioHostUrl = audioHostUrl,
            SignalingUrl = signalingUrl,
            TurnControlUrl = turnControlUrl
        )

        val meeting = Meeting(
            ExternalMeetingId = externalMeetingId,
            MediaPlacement = mediaPlacement,
            MediaRegion = meetingMap["MediaRegion"] as? String ?: "us-east-1",
            MeetingId = meetingId
        )

        val attendeeId = attendeeMap["AttendeeId"] as? String ?: throw IllegalArgumentException("Missing AttendeeId")
        val externalUserId = attendeeMap["ExternalUserId"] as? String ?: ""
        val joinToken = attendeeMap["JoinToken"] as? String ?: throw IllegalArgumentException("Missing JoinToken")

        localAttendeeId = attendeeId
        desiredMuted = false

        val attendee = Attendee(
            AttendeeId = attendeeId,
            ExternalUserId = externalUserId,
            JoinToken = joinToken
        )

        val configuration = MeetingSessionConfiguration(
            CreateMeetingResponse(meeting),
            CreateAttendeeResponse(attendee)
        )

        val session = DefaultMeetingSession(
            configuration,
            ConsoleLogger(),
            context
        )

        meetingSession = session

        session.audioVideo.addAudioVideoObserver(this)
        session.audioVideo.addVideoTileObserver(this)
        session.audioVideo.addRealtimeObserver(this)

        session.audioVideo.start()
        // Enable RECEIVING remote video. This is the master switch  it calls
        // VideoClient.setReceiving(true) under the hood. Without it the video
        // client never accepts ANY inbound video frames, so onRemoteVideoSourceAvailable
        // can fire and we can call updateVideoSourceSubscriptions all we want, but
        // onVideoTileAdded for the remote tile never fires and the peer is stuck on
        // "Waiting for video". updateVideoSourceSubscriptions only PICKS sources; it
        // does NOT flip the receiving flag. Audio + local self-view work without this,
        // which is exactly the symptom we were seeing. Always start it (cheap no-op for
        // audio-only calls  no remote video sources will be advertised).
        session.audioVideo.startRemoteVideo()
        if (videoEnabled) {
            session.audioVideo.startLocalVideo()
        }
    }

    private fun leaveMeeting(resetAudio: Boolean = true) {
        mainHandler.removeCallbacks(audioResetRunnable)
        meetingSession?.let { session ->
            try {
                session.audioVideo.realtimeLocalUnmute()
            } catch (e: Exception) {
                Log.w(TAG, "Unable to unmute before leaving meeting", e)
            }
            try {
                session.audioVideo.stopLocalVideo()
            } catch (e: Exception) {
                Log.w(TAG, "Unable to stop local video before leaving meeting", e)
            }
            try {
                session.audioVideo.stopRemoteVideo()
            } catch (e: Exception) {
                Log.w(TAG, "Unable to stop remote video before leaving meeting", e)
            }
            try {
                session.audioVideo.stop()
            } catch (e: Exception) {
                Log.w(TAG, "Unable to stop meeting audio/video", e)
            } finally {
                session.audioVideo.removeAudioVideoObserver(this)
                session.audioVideo.removeVideoTileObserver(this)
                session.audioVideo.removeRealtimeObserver(this)
            }
        }
        meetingSession = null
        localTileId = null
        remoteTileId = null
        localAttendeeId = null
        desiredMuted = false
        if (resetAudio) {
            resetAndroidAudioAfterCall()
            mainHandler.postDelayed(audioResetRunnable, AUDIO_RESET_DELAY_MS)
        }
    }

    private fun applyLocalMute(audioVideo: AudioVideoFacade, muted: Boolean) {
        if (muted) {
            audioVideo.realtimeLocalMute()
            sendEvent("localMuted")
        } else {
            audioVideo.realtimeLocalUnmute()
            sendEvent("localUnmuted")
        }
    }

    private fun resetAndroidAudioAfterCall() {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        try {
            audioManager.isMicrophoneMute = false
        } catch (e: Exception) {
            Log.w(TAG, "Unable to clear microphone mute after call", e)
        }
        try {
            audioManager.isSpeakerphoneOn = false
        } catch (e: Exception) {
            Log.w(TAG, "Unable to clear speaker route after call", e)
        }
        try {
            if (audioManager.mode == AudioManager.MODE_IN_COMMUNICATION) {
                audioManager.mode = AudioManager.MODE_NORMAL
            }
        } catch (e: Exception) {
            Log.w(TAG, "Unable to reset audio mode after call", e)
        }
    }

    private fun setSpeaker(enabled: Boolean) {
        val audioVideo = meetingSession?.audioVideo ?: return
        val devices = audioVideo.listAudioDevices()
        val targetType = if (enabled) MediaDeviceType.AUDIO_BUILTIN_SPEAKER else MediaDeviceType.AUDIO_HANDSET
        val device = devices.find { it.type == targetType }
        if (device != null) {
            audioVideo.chooseAudioDevice(device)
        } else if (!enabled) {
            // fallback to wired headset if handset not found
            val fallbackDevice = devices.find { it.type == MediaDeviceType.AUDIO_WIRED_HEADSET }
            if (fallbackDevice != null) {
                audioVideo.chooseAudioDevice(fallbackDevice)
            }
        }
    }

    /**
     * Mirror the local self-view ONLY when the front camera is active, the way
     * users expect a selfie preview to behave. Back camera is never mirrored.
     * `mirror` is a render-only flag on the local DefaultVideoRenderView, so the
     * stream sent to the remote peer is unaffected  they always see us
     * correctly oriented, and captured/published frames are not flipped.
     */
    private fun applyLocalMirror() {
        val isFront = meetingSession?.audioVideo?.getActiveCamera()?.type ==
            MediaDeviceType.VIDEO_FRONT_CAMERA
        activeLocalView?.getVideoRenderView()?.mirror = isFront
    }

    fun registerVideoView(view: ChimeVideoPlatformView, isLocal: Boolean) {
        mainHandler.post {
            if (isLocal) {
                activeLocalView = view
                localTileId?.let { tileId ->
                    meetingSession?.audioVideo?.bindVideoView(view.getVideoRenderView(), tileId)
                }
                applyLocalMirror()
            } else {
                activeRemoteView = view
                remoteTileId?.let { tileId ->
                    meetingSession?.audioVideo?.bindVideoView(view.getVideoRenderView(), tileId)
                }
            }
        }
    }

    fun unregisterVideoView(view: ChimeVideoPlatformView) {
        mainHandler.post {
            if (view == activeLocalView) {
                activeLocalView = null
                localTileId?.let { tileId ->
                    meetingSession?.audioVideo?.unbindVideoView(tileId)
                }
            } else if (view == activeRemoteView) {
                activeRemoteView = null
                remoteTileId?.let { tileId ->
                    meetingSession?.audioVideo?.unbindVideoView(tileId)
                }
            }
        }
    }

    private fun sendEvent(eventName: String, data: Map<String, Any> = emptyMap()) {
        mainHandler.post {
            eventSink?.success(mapOf("event" to eventName) + data)
        }
    }

    // StreamHandler implementations
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    // AudioVideoObserver implementations
    override fun onAudioSessionStarted(reconnecting: Boolean) {
        meetingSession?.audioVideo?.let { audioVideo ->
            applyLocalMute(audioVideo, desiredMuted)
        }
        sendEvent(if (reconnecting) "reconnecting" else "connected")
    }

    override fun onAudioSessionStartedConnecting(reconnecting: Boolean) {
        sendEvent("connecting")
    }

    override fun onAudioSessionStopped(sessionStatus: MeetingSessionStatus) {
        sendEvent("disconnected")
    }

    override fun onAudioSessionCancelledReconnect() {
        sendEvent("disconnected")
    }

    override fun onConnectionRecovered() {
        sendEvent("connected")
    }

    override fun onAudioSessionDropped() {
        sendEvent("failed")
    }

    override fun onConnectionBecamePoor() {}
    override fun onVideoSessionStartedConnecting() {}
    override fun onVideoSessionStarted(sessionStatus: MeetingSessionStatus) {}
    override fun onVideoSessionStopped(sessionStatus: MeetingSessionStatus) {}
    override fun onCameraSendAvailabilityUpdated(available: Boolean) {}

    // Chime SDK 0.21.0 does NOT auto-deliver remote video. When a peer turns on
    // their camera the SDK advertises the source here, and we must explicitly
    // subscribe or onVideoTileAdded never fires for the remote tile  which is
    // exactly why remote video never rendered. Subscribe to every advertised
    // source at high priority/resolution (1:1 calls only ever have one).
    override fun onRemoteVideoSourceAvailable(sources: List<RemoteVideoSource>) {
        val audioVideo = meetingSession?.audioVideo ?: return
        if (sources.isEmpty()) return
        val subscriptions = sources.associateWith {
            VideoSubscriptionConfiguration(VideoPriority.Highest, VideoResolution.High)
        }
        audioVideo.updateVideoSourceSubscriptions(subscriptions, emptyArray())
    }

    override fun onRemoteVideoSourceUnavailable(sources: List<RemoteVideoSource>) {
        val audioVideo = meetingSession?.audioVideo ?: return
        if (sources.isEmpty()) return
        audioVideo.updateVideoSourceSubscriptions(emptyMap(), sources.toTypedArray())
    }

    // VideoTileObserver implementations
    override fun onVideoTileAdded(tileState: VideoTileState) {
        if (tileState.isLocalTile) {
            localTileId = tileState.tileId
            sendEvent("localVideoEnabled")
            activeLocalView?.let { view ->
                meetingSession?.audioVideo?.bindVideoView(view.getVideoRenderView(), tileState.tileId)
            }
            applyLocalMirror()
        } else {
            remoteTileId = tileState.tileId
            sendEvent("remoteVideoEnabled")
            activeRemoteView?.let { view ->
                meetingSession?.audioVideo?.bindVideoView(view.getVideoRenderView(), tileState.tileId)
            }
        }
    }

    override fun onVideoTileRemoved(tileState: VideoTileState) {
        if (tileState.isLocalTile) {
            localTileId = null
            sendEvent("localVideoDisabled")
            meetingSession?.audioVideo?.unbindVideoView(tileState.tileId)
        } else {
            remoteTileId = null
            sendEvent("remoteVideoDisabled")
            meetingSession?.audioVideo?.unbindVideoView(tileState.tileId)
        }
    }

    override fun onVideoTilePaused(tileState: VideoTileState) {}
    override fun onVideoTileResumed(tileState: VideoTileState) {}
    override fun onVideoTileSizeChanged(tileState: VideoTileState) {}

    // RealtimeObserver implementations
    override fun onAttendeesJoined(attendeeInfo: Array<AttendeeInfo>) {
        for (info in attendeeInfo) {
            if (info.attendeeId != localAttendeeId) {
                sendEvent("remoteJoined")
            }
        }
    }

    override fun onAttendeesLeft(attendeeInfo: Array<AttendeeInfo>) {
        for (info in attendeeInfo) {
            if (info.attendeeId != localAttendeeId) {
                sendEvent("remoteLeft")
            }
        }
    }

    override fun onAttendeesDropped(attendeeInfo: Array<AttendeeInfo>) {
        for (info in attendeeInfo) {
            if (info.attendeeId != localAttendeeId) {
                sendEvent("remoteLeft")
            }
        }
    }

    override fun onAttendeesMuted(attendeeInfo: Array<AttendeeInfo>) {
        for (info in attendeeInfo) {
            if (info.attendeeId == localAttendeeId) {
                desiredMuted = true
                sendEvent("localMuted")
            }
        }
    }

    override fun onAttendeesUnmuted(attendeeInfo: Array<AttendeeInfo>) {
        for (info in attendeeInfo) {
            if (info.attendeeId == localAttendeeId) {
                desiredMuted = false
                sendEvent("localUnmuted")
            }
        }
    }
    override fun onSignalStrengthChanged(signalUpdates: Array<SignalUpdate>) {}
    override fun onVolumeChanged(volumeUpdates: Array<VolumeUpdate>) {}
}
