import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let callAudioSession = IOSCallAudioSession()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      callAudioSession.attach(to: controller.binaryMessenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

final class IOSCallAudioSession {
  private let channelName = "com.danish.m2m/ios_audio_session"
  private var channel: FlutterMethodChannel?
  private var isConfiguredForCall = false
  private var lastIsVideoCall = false
  private var lastDefaultToSpeaker = false

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "ios_audio_session_unavailable", message: "Audio session manager is unavailable", details: nil))
        return
      }

      switch call.method {
      case "configureForCall":
        let args = call.arguments as? [String: Any]
        let isVideo = args?["isVideo"] as? Bool ?? false
        let defaultToSpeaker = args?["defaultToSpeaker"] as? Bool ?? isVideo
        self.configureForCall(isVideo: isVideo, defaultToSpeaker: defaultToSpeaker, result: result)
      case "reactivateForCall":
        self.reactivateForCall(result: result)
      case "deactivateAfterCall":
        self.deactivateAfterCall(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleInterruption(_:)),
      name: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance()
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleRouteChange(_:)),
      name: AVAudioSession.routeChangeNotification,
      object: AVAudioSession.sharedInstance()
    )
  }

  private func configureForCall(
    isVideo: Bool,
    defaultToSpeaker: Bool,
    result: @escaping FlutterResult
  ) {
    do {
      lastIsVideoCall = isVideo
      lastDefaultToSpeaker = defaultToSpeaker
      try applyCallCategory(isVideo: isVideo, defaultToSpeaker: defaultToSpeaker)
      try AVAudioSession.sharedInstance().setActive(true)
      isConfiguredForCall = true
      NSLog("iOS audio session configured and activated for call video=%@", isVideo ? "true" : "false")
      result(nil)
    } catch {
      NSLog("iOS audio session configure failed: %@", error.localizedDescription)
      result(FlutterError(code: "ios_audio_session_configure_failed", message: error.localizedDescription, details: nil))
    }
  }

  private func reactivateForCall(result: @escaping FlutterResult) {
    guard isConfiguredForCall else {
      result(nil)
      return
    }

    do {
      try applyCallCategory(isVideo: lastIsVideoCall, defaultToSpeaker: lastDefaultToSpeaker)
      try AVAudioSession.sharedInstance().setActive(true)
      NSLog("iOS audio session reactivated for call")
      result(nil)
    } catch {
      NSLog("iOS audio session reactivate failed: %@", error.localizedDescription)
      result(FlutterError(code: "ios_audio_session_reactivate_failed", message: error.localizedDescription, details: nil))
    }
  }

  private func deactivateAfterCall(result: @escaping FlutterResult) {
    do {
      isConfiguredForCall = false
      try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
      NSLog("iOS audio session deactivated after call")
      result(nil)
    } catch {
      NSLog("iOS audio session deactivate failed: %@", error.localizedDescription)
      result(FlutterError(code: "ios_audio_session_deactivate_failed", message: error.localizedDescription, details: nil))
    }
  }

  private func applyCallCategory(isVideo: Bool, defaultToSpeaker: Bool) throws {
    var options: AVAudioSession.CategoryOptions = [.allowBluetooth]
    if #available(iOS 10.0, *) {
      options.insert(.allowBluetoothA2DP)
    }
    if defaultToSpeaker {
      options.insert(.defaultToSpeaker)
    }

    try AVAudioSession.sharedInstance().setCategory(
      .playAndRecord,
      mode: isVideo ? .videoChat : .voiceChat,
      options: options
    )
  }

  @objc private func handleInterruption(_ notification: Notification) {
    guard
      let userInfo = notification.userInfo,
      let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: typeValue)
    else {
      return
    }

    switch type {
    case .began:
      NSLog("iOS audio session interrupted began")
      channel?.invokeMethod("audioSessionInterrupted", arguments: ["phase": "began"])
    case .ended:
      NSLog("iOS audio session interrupted ended")
      if isConfiguredForCall {
        do {
          try applyCallCategory(isVideo: lastIsVideoCall, defaultToSpeaker: lastDefaultToSpeaker)
          try AVAudioSession.sharedInstance().setActive(true)
          NSLog("iOS audio session activated after interruption")
        } catch {
          NSLog("iOS audio session interruption reactivation failed: %@", error.localizedDescription)
        }
      }
      channel?.invokeMethod("audioSessionInterrupted", arguments: ["phase": "ended"])
    @unknown default:
      NSLog("iOS audio session interrupted unknown")
    }
  }

  @objc private func handleRouteChange(_ notification: Notification) {
    let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 0
    let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
    NSLog("iOS audio session route changed reason=%lu", reasonValue)
    if isConfiguredForCall {
      do {
        try AVAudioSession.sharedInstance().setActive(true)
      } catch {
        NSLog("iOS audio session route-change activation failed: %@", error.localizedDescription)
      }
    }
    channel?.invokeMethod("audioSessionRouteChanged", arguments: ["reason": reason?.rawValue ?? reasonValue])
  }
}
