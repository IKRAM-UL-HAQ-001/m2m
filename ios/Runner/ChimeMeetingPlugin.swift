import Flutter
import UIKit
import AmazonChimeSDK
import AVFoundation

public class ChimeMeetingPlugin: NSObject, FlutterPlugin, AudioVideoObserver, VideoTileObserver, RealtimeObserver {
    private var meetingSession: MeetingSession?
    private var eventSink: FlutterEventSink?

    private var localTileId: Int?
    private var remoteTileId: Int?

    private var activeLocalView: ChimeVideoPlatformView?
    private var activeRemoteView: ChimeVideoPlatformView?

    private var localAttendeeId: String?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.danish.m2m/chime", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "com.danish.m2m/chime_events", binaryMessenger: registrar.messenger())

        let instance = ChimeMeetingPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)

        registrar.register(
            ChimeVideoPlatformViewFactory(plugin: instance),
            withId: "com.danish.m2m/chime_video"
        )
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "join":
            guard let args = call.arguments as? [String: Any],
                  let meetingMap = args["meeting"] as? [String: Any],
                  let attendeeMap = args["attendee"] as? [String: Any] else {
                result(FlutterError(code: "invalid_arguments", message: "Arguments were invalid", details: nil))
                return
            }
            let videoEnabled = args["videoEnabled"] as? Bool ?? false
            joinMeeting(meetingMap: meetingMap, attendeeMap: attendeeMap, videoEnabled: videoEnabled, result: result)
        case "leave":
            leaveMeeting()
            result(nil)
        case "setMuted":
            guard let args = call.arguments as? [String: Any],
                  let muted = args["muted"] as? Bool else {
                result(FlutterError(code: "invalid_arguments", message: "Muted parameter missing", details: nil))
                return
            }
            if muted {
                meetingSession?.audioVideo.realtimeLocalMute()
            } else {
                meetingSession?.audioVideo.realtimeLocalUnmute()
            }
            result(nil)
        case "setCameraEnabled":
            guard let args = call.arguments as? [String: Any],
                  let enabled = args["enabled"] as? Bool else {
                result(FlutterError(code: "invalid_arguments", message: "Enabled parameter missing", details: nil))
                return
            }
            if enabled {
                meetingSession?.audioVideo.startLocalVideo()
            } else {
                meetingSession?.audioVideo.stopLocalVideo()
            }
            result(nil)
        case "switchCamera":
            meetingSession?.audioVideo.switchCamera()
            result(nil)
        case "setSpeakerEnabled":
            guard let args = call.arguments as? [String: Any],
                  let enabled = args["enabled"] as? Bool else {
                result(FlutterError(code: "invalid_arguments", message: "Enabled parameter missing", details: nil))
                return
            }
            setSpeaker(enabled: enabled)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func joinMeeting(
        meetingMap: [String: Any],
        attendeeMap: [String: Any],
        videoEnabled: Bool,
        result: @escaping FlutterResult
    ) {
        leaveMeeting()

        guard let meetingId = meetingMap["MeetingId"] as? String,
              let mediaPlacementMap = meetingMap["MediaPlacement"] as? [String: Any],
              let audioHostUrl = mediaPlacementMap["AudioHostUrl"] as? String,
              let audioFallbackUrl = mediaPlacementMap["AudioFallbackUrl"] as? String,
              let signalingUrl = mediaPlacementMap["SignalingUrl"] as? String,
              let turnControlUrl = mediaPlacementMap["TurnControlUrl"] as? String else {
            result(FlutterError(code: "invalid_arguments", message: "Invalid meeting schema", details: nil))
            return
        }

        let externalMeetingId = meetingMap["ExternalMeetingId"] as? String ?? ""
        let eventIngestionUrl = mediaPlacementMap["EventIngestionUrl"] as? String

        guard let attendeeId = attendeeMap["AttendeeId"] as? String,
              let joinToken = attendeeMap["JoinToken"] as? String else {
            result(FlutterError(code: "invalid_arguments", message: "Invalid attendee schema", details: nil))
            return
        }
        let externalUserId = attendeeMap["ExternalUserId"] as? String ?? ""

        self.localAttendeeId = attendeeId

        let mediaPlacement = MediaPlacement(
            audioFallbackUrl: audioFallbackUrl,
            audioHostUrl: audioHostUrl,
            signalingUrl: signalingUrl,
            turnControlUrl: turnControlUrl,
            eventIngestionUrl: eventIngestionUrl
        )

        let meeting = Meeting(
            externalMeetingId: externalMeetingId,
            mediaPlacement: mediaPlacement,
            mediaRegion: meetingMap["MediaRegion"] as? String ?? "us-east-1",
            meetingId: meetingId
        )

        let attendee = Attendee(
            attendeeId: attendeeId,
            externalUserId: externalUserId,
            joinToken: joinToken
        )

        let configuration = MeetingSessionConfiguration(
            createMeetingResponse: CreateMeetingResponse(meeting: meeting),
            createAttendeeResponse: CreateAttendeeResponse(attendee: attendee)
        )

        let logger = ConsoleLogger(name: "ChimeSDK")
        let session = DefaultMeetingSession(configuration: configuration, logger: logger)
        self.meetingSession = session

        session.audioVideo.addAudioVideoObserver(observer: self)
        session.audioVideo.addVideoTileObserver(observer: self)
        session.audioVideo.addRealtimeObserver(observer: self)

        do {
            try session.audioVideo.start()
            if videoEnabled {
                try session.audioVideo.startLocalVideo()
            }
            result(nil)
        } catch {
            result(FlutterError(code: "join_failed", message: error.localizedDescription, details: nil))
        }
    }

    private func leaveMeeting() {
        if let session = meetingSession {
            session.audioVideo.stop()
            session.audioVideo.removeAudioVideoObserver(observer: self)
            session.audioVideo.removeVideoTileObserver(observer: self)
            session.audioVideo.removeRealtimeObserver(observer: self)
        }
        meetingSession = nil
        localTileId = nil
        remoteTileId = nil
        localAttendeeId = nil
    }

    private func setSpeaker(enabled: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.overrideOutputAudioPort(enabled ? .speaker : .none)
        } catch {
            NSLog("Failed to override audio port: %@", error.localizedDescription)
        }
    }

    func registerVideoView(view: ChimeVideoPlatformView, isLocal: Bool) {
        DispatchQueue.main.async {
            if isLocal {
                self.activeLocalView = view
                if let tileId = self.localTileId {
                    self.meetingSession?.audioVideo.bindVideoView(videoView: view.getVideoRenderView(), tileId: tileId)
                }
            } else {
                self.activeRemoteView = view
                if let tileId = self.remoteTileId {
                    self.meetingSession?.audioVideo.bindVideoView(videoView: view.getVideoRenderView(), tileId: tileId)
                }
            }
        }
    }

    func unregisterVideoView(view: ChimeVideoPlatformView) {
        DispatchQueue.main.async {
            if view === self.activeLocalView {
                self.activeLocalView = nil
                if let tileId = self.localTileId {
                    self.meetingSession?.audioVideo.unbindVideoView(tileId: tileId)
                }
            } else if view === self.activeRemoteView {
                self.activeRemoteView = nil
                if let tileId = self.remoteTileId {
                    self.meetingSession?.audioVideo.unbindVideoView(tileId: tileId)
                }
            }
        }
    }

    private func sendEvent(eventName: String) {
        DispatchQueue.main.async {
            self.eventSink?(["event": eventName])
        }
    }

    // MARK: - FlutterStreamHandler
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    // MARK: - AudioVideoObserver
    public func audioVideoDidStart(sessionStatus: MeetingSessionStatus) {
        sendEvent(eventName: "connected")
    }

    public func audioVideoDidStartConnecting(reconnecting: Bool) {
        sendEvent(eventName: reconnecting ? "reconnecting" : "connecting")
    }

    public func audioVideoDidStop(sessionStatus: MeetingSessionStatus) {
        sendEvent(eventName: "disconnected")
    }

    public func audioVideoDidCancel() {
        sendEvent(eventName: "disconnected")
    }

    public func connectionDidBecomePoor() {}
    public func connectionDidRecover() {
        sendEvent(eventName: "connected")
    }

    public func videoSessionDidStartConnecting() {}
    public func videoSessionDidStart(sessionStatus: MeetingSessionStatus) {}
    public func videoSessionDidStop(sessionStatus: MeetingSessionStatus) {}

    // MARK: - VideoTileObserver
    public func videoTileDidAdd(tileState: VideoTileState) {
        if tileState.isLocalTile {
            localTileId = tileState.tileId
            sendEvent(eventName: "localVideoEnabled")
            if let view = activeLocalView {
                meetingSession?.audioVideo.bindVideoView(videoView: view.getVideoRenderView(), tileId: tileState.tileId)
            }
        } else {
            remoteTileId = tileState.tileId
            sendEvent(eventName: "remoteVideoEnabled")
            if let view = activeRemoteView {
                meetingSession?.audioVideo.bindVideoView(videoView: view.getVideoRenderView(), tileId: tileState.tileId)
            }
        }
    }

    public func videoTileDidRemove(tileState: VideoTileState) {
        if tileState.isLocalTile {
            localTileId = nil
            sendEvent(eventName: "localVideoDisabled")
            meetingSession?.audioVideo.unbindVideoView(tileId: tileState.tileId)
        } else {
            remoteTileId = nil
            sendEvent(eventName: "remoteVideoDisabled")
            meetingSession?.audioVideo.unbindVideoView(tileId: tileState.tileId)
        }
    }

    public func videoTileDidPause(tileState: VideoTileState) {}
    public func videoTileDidResume(tileState: VideoTileState) {}
    public func videoTileSizeDidChange(tileState: VideoTileState) {}

    // MARK: - RealtimeObserver
    public func attendeesDidJoin(attendeeInfo: [AttendeeInfo]) {
        for info in attendeeInfo {
            if info.attendeeId != localAttendeeId {
                sendEvent(eventName: "remoteJoined")
            }
        }
    }

    public func attendeesDidLeave(attendeeInfo: [AttendeeInfo]) {
        for info in attendeeInfo {
            if info.attendeeId != localAttendeeId {
                sendEvent(eventName: "remoteLeft")
            }
        }
    }

    public func attendeesDidDrop(attendeeInfo: [AttendeeInfo]) {
        for info in attendeeInfo {
            if info.attendeeId != localAttendeeId {
                sendEvent(eventName: "remoteLeft")
            }
        }
    }

    public func volumeDidChange(volumeUpdates: [VolumeUpdate]) {}
    public func signalStrengthDidChange(signalUpdates: [SignalUpdate]) {}
    public func attendeesDidMute(attendeeInfo: [AttendeeInfo]) {}
    public func attendeesDidUnmute(attendeeInfo: [AttendeeInfo]) {}
}
