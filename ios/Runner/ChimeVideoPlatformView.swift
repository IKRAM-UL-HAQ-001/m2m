import Flutter
import UIKit
import AmazonChimeSDK

class ChimeVideoPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
    private let plugin: ChimeMeetingPlugin

    init(plugin: ChimeMeetingPlugin) {
        self.plugin = plugin
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let creationParams = args as? [String: Any]
        return ChimeVideoPlatformView(frame: frame, plugin: plugin, creationParams: creationParams)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class ChimeVideoPlatformView: NSObject, FlutterPlatformView {
    private let videoRenderView: DefaultVideoRenderView
    private let plugin: ChimeMeetingPlugin
    private let isLocal: Bool

    init(frame: CGRect, plugin: ChimeMeetingPlugin, creationParams: [String: Any]?) {
        self.videoRenderView = DefaultVideoRenderView(frame: frame)
        self.plugin = plugin
        self.isLocal = creationParams?["isLocal"] as? Bool ?? false
        super.init()

        plugin.registerVideoView(view: self, isLocal: isLocal)
    }

    func view() -> UIView {
        return videoRenderView
    }

    func getVideoRenderView() -> DefaultVideoRenderView {
        return videoRenderView
    }

    deinit {
        plugin.unregisterVideoView(view: self)
    }
}
