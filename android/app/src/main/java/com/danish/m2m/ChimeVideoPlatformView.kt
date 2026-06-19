package com.danish.m2m

import android.content.Context
import android.view.View
import com.amazonaws.services.chime.sdk.meetings.audiovideo.video.DefaultVideoRenderView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class ChimeVideoPlatformViewFactory(private val plugin: ChimeMeetingPlugin) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as? Map<String, Any>
        return ChimeVideoPlatformView(context, plugin, creationParams)
    }
}

class ChimeVideoPlatformView(
    context: Context,
    private val plugin: ChimeMeetingPlugin,
    creationParams: Map<String, Any>?
) : PlatformView {
    private val videoRenderView: DefaultVideoRenderView = DefaultVideoRenderView(context)
    private val isLocal: Boolean = creationParams?.get("isLocal") as? Boolean ?: false

    init {
        plugin.registerVideoView(this, isLocal)
    }

    fun getVideoRenderView(): DefaultVideoRenderView {
        return videoRenderView
    }

    override fun getView(): View {
        return videoRenderView
    }

    override fun dispose() {
        plugin.unregisterVideoView(this)
    }
}
