package io.github.harikrishnan_cr.media_compressor

import android.content.Context
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.os.Handler
import android.os.Looper
import java.io.File

class MediaCompressorPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context
    private lateinit var compressor: NativeCompressor
    private var progressSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        compressor = NativeCompressor(context)

        channel = MethodChannel(binding.binaryMessenger, "native_compressor")
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "native_compressor/progress")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { progressSink = events }
            override fun onCancel(arguments: Any?) { progressSink = null }
        })
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "compressImage" -> handleCompressImage(call, result)
            "compressVideo" -> handleCompressVideo(call, result)
            "cancel" -> { compressor.cancelVideo(); result.success(null) }
            "release" -> handleRelease(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleCompressImage(call: MethodCall, result: Result) {
        val path = call.argument<String>("path")
        val quality = call.argument<Int>("quality") ?: 80
        val maxWidth = call.argument<Int>("maxWidth")
        val maxHeight = call.argument<Int>("maxHeight")

        if (path == null) { result.error("INVALID_ARGUMENT", "Path is required for image compression", null); return }
        if (quality !in 0..100) { result.error("INVALID_ARGUMENT", "Quality must be between 0 and 100", null); return }
        if (maxWidth != null && maxWidth <= 0) { result.error("INVALID_ARGUMENT", "maxWidth must be greater than 0", null); return }
        if (maxHeight != null && maxHeight <= 0) { result.error("INVALID_ARGUMENT", "maxHeight must be greater than 0", null); return }

        compressor.compressImage(path, quality, maxWidth, maxHeight) { p, e ->
            if (e != null) result.error(e.code, e.message, e.details) else result.success(p)
        }
    }

    private fun handleCompressVideo(call: MethodCall, result: Result) {
        val path = call.argument<String>("path")
        val quality = call.argument<String>("quality") ?: "medium"

        if (path == null) { result.error("INVALID_ARGUMENT", "Path is required for video compression", null); return }
        if (quality.lowercase() !in listOf("low", "medium", "high")) {
            result.error("INVALID_ARGUMENT", "Quality must be one of: low, medium, high", null); return
        }

        val progressCallback: (Float) -> Unit = { progress ->
            Handler(Looper.getMainLooper()).post {
                progressSink?.success(mapOf("progress" to progress, "percentage" to (progress * 100).toInt()))
            }
        }

        compressor.compressVideo(path, quality,
            callback = { p, e -> if (e != null) result.error(e.code, e.message, e.details) else result.success(p) },
            progressCallback = progressCallback)
    }

    // C1 fix: only delete files that live inside the plugin's cache directory.
    private fun handleRelease(call: MethodCall, result: Result) {
        val path = call.argument<String>("path")
        if (!path.isNullOrEmpty()) {
            try {
                val target = File(path).canonicalFile
                val cacheRoot = context.cacheDir.canonicalFile
                if (target.path.startsWith(cacheRoot.path + File.separator) && target.exists()) {
                    target.delete()
                }
            } catch (_: Exception) { /* best-effort */ }
        }
        result.success(null)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        compressor.dispose()
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        progressSink = null
    }
}