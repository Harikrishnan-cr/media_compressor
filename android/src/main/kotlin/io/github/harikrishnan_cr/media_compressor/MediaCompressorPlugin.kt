package io.github.harikrishnan_cr.media_compressor

import android.content.Context
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class MediaCompressorPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var compressor: NativeCompressor

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        compressor = NativeCompressor(context)
        
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "native_compressor")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "compressImage" -> handleCompressImage(call, result)
            "compressVideo" -> handleCompressVideo(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleCompressImage(call: MethodCall, result: Result) {
        val path = call.argument<String>("path")
        val quality = call.argument<Int>("quality") ?: 80
        val maxWidth = call.argument<Int>("maxWidth")
        val maxHeight = call.argument<Int>("maxHeight")

        if (path == null) {
            result.error("INVALID_ARGUMENT", "Path is required for image compression", null)
            return
        }

        if (quality !in 0..100) {
            result.error("INVALID_ARGUMENT", "Quality must be between 0 and 100", null)
            return
        }

        if (maxWidth != null && maxWidth <= 0) {
            result.error("INVALID_ARGUMENT", "maxWidth must be greater than 0", null)
            return
        }

        if (maxHeight != null && maxHeight <= 0) {
            result.error("INVALID_ARGUMENT", "maxHeight must be greater than 0", null)
            return
        }

        compressor.compressImage(path, quality, maxWidth, maxHeight) { compressedPath, error ->
            if (error != null) {
                result.error(error.code, error.message, error.details)
            } else {
                result.success(compressedPath)
            }
        }
    }

    private fun handleCompressVideo(call: MethodCall, result: Result) {
        val path = call.argument<String>("path")
        val quality = call.argument<String>("quality") ?: "medium"

        if (path == null) {
            result.error("INVALID_ARGUMENT", "Path is required for video compression", null)
            return
        }

        val validQualities = listOf("low", "medium", "high")
        if (quality.lowercase() !in validQualities) {
            result.error("INVALID_ARGUMENT", "Quality must be one of: low, medium, high", null)
            return
        }

        compressor.compressVideo(path, quality) { compressedPath, error ->
            if (error != null) {
                result.error(error.code, error.message, error.details)
            } else {
                result.success(compressedPath)
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}