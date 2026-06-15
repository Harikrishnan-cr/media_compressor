package io.github.harikrishnan_cr.media_compressor

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.exifinterface.media.ExifInterface
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.ScaleAndRotateTransformation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.UUID
import android.util.Log
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

data class CompressionError(
    val code: String,
    val message: String,
    val details: Any? = null
)

class NativeCompressor(private val context: Context) {

    companion object {
        private const val TAG = "NativeCompressor"
    }

    // M2 fix: one managed scope cancelled on engine detach (no orphaned work).
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    // Reference to the active transformer so cancel() can abort it.
    @Volatile
    private var activeTransformer: Transformer? = null

    // C2 fix: single-flight video guard (matches web/iOS contract).
    @Volatile
    private var videoInProgress = false

    /// Cancel any in-flight video compression. Safe no-op otherwise.
    fun cancelVideo() {
        val t = activeTransformer ?: return
        Handler(Looper.getMainLooper()).post {
            try { t.cancel() } catch (e: Exception) { Log.e(TAG, "cancel failed", e) }
        }
    }

    /// Cancel all work and release the scope. Call on engine detach.
    fun dispose() {
        cancelVideo()
        scope.cancel()
    }

    // ========================= IMAGE =========================

    fun compressImage(
        imagePath: String, quality: Int, maxWidth: Int?, maxHeight: Int?,
        callback: (String?, CompressionError?) -> Unit
    ) {
        scope.launch {
            try {
                val result = compressImageInternal(imagePath, quality, maxWidth, maxHeight)
                withContext(Dispatchers.Main) { callback(result, null) }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(null, CompressionError("COMPRESSION_ERROR",
                        e.message ?: "Unknown error", e.stackTraceToString()))
                }
            }
        }
    }

    private suspend fun compressImageInternal(
        imagePath: String, quality: Int, maxWidth: Int?, maxHeight: Int?
    ): String = withContext(Dispatchers.IO) {
        val inputFile = File(imagePath)
        if (!inputFile.exists()) throw IOException("Image file not found at path: $imagePath")

        val bitmap = decodeBitmapWithOrientation(imagePath)
            ?: throw IOException("Failed to decode image from path: $imagePath")

        try {
            val resized = if (maxWidth != null && maxHeight != null)
                resizeBitmap(bitmap, maxWidth, maxHeight) else bitmap
            val outputFile = createOutputFile("jpg")
            FileOutputStream(outputFile).use { os ->
                if (!resized.compress(Bitmap.CompressFormat.JPEG, quality, os))
                    throw IOException("Failed to compress image")
            }
            if (resized != bitmap) resized.recycle()
            bitmap.recycle()
            outputFile.absolutePath
        } catch (e: Exception) {
            bitmap.recycle(); throw e
        }
    }

    private fun decodeBitmapWithOrientation(imagePath: String): Bitmap? {
        val options = BitmapFactory.Options().apply {
            inJustDecodeBounds = false
            inPreferredConfig = Bitmap.Config.RGB_565
        }
        val bitmap = BitmapFactory.decodeFile(imagePath, options) ?: return null
        val exif = try { ExifInterface(imagePath) } catch (e: IOException) { return bitmap }
        val orientation = exif.getAttributeInt(
            ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
        return rotateBitmap(bitmap, orientation)
    }

    private fun rotateBitmap(bitmap: Bitmap, orientation: Int): Bitmap {
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> { matrix.postRotate(90f); matrix.postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_TRANSVERSE -> { matrix.postRotate(270f); matrix.postScale(-1f, 1f) }
            else -> return bitmap
        }
        return try {
            val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            if (rotated != bitmap) bitmap.recycle()
            rotated
        } catch (e: OutOfMemoryError) { e.printStackTrace(); bitmap }
    }

    private fun resizeBitmap(bitmap: Bitmap, maxWidth: Int, maxHeight: Int): Bitmap {
        val width = bitmap.width; val height = bitmap.height
        val ratio = minOf(maxWidth.toFloat() / width, maxHeight.toFloat() / height, 1f)
        if (ratio >= 1f) return bitmap
        return try {
            Bitmap.createScaledBitmap(bitmap, (width * ratio).toInt(), (height * ratio).toInt(), true)
        } catch (e: OutOfMemoryError) { e.printStackTrace(); bitmap }
    }

    // ========================= VIDEO (Media3 Transformer) =========================

    fun compressVideo(
        videoPath: String, quality: String,
        callback: (String?, CompressionError?) -> Unit,
        progressCallback: ((Float) -> Unit)? = null
    ) {
        if (videoInProgress) {
            callback(null, CompressionError("BUSY", "Another video compression is in progress"))
            return
        }
        videoInProgress = true
        scope.launch {
            try {
                val result = compressVideoInternal(videoPath, quality, progressCallback)
                withContext(Dispatchers.Main) { callback(result, null) }
            } catch (e: Exception) {
                Log.e(TAG, "Video compression error", e)
                withContext(Dispatchers.Main) {
                    callback(null, CompressionError("COMPRESSION_ERROR",
                        e.message ?: "Unknown error", e.stackTraceToString()))
                }
            } finally {
                videoInProgress = false
                activeTransformer = null
            }
        }
    }

    private suspend fun compressVideoInternal(
        videoPath: String, quality: String, progressCallback: ((Float) -> Unit)? = null
    ): String = withContext(Dispatchers.IO) {
        val inputFile = File(videoPath)
        if (!inputFile.exists()) throw IOException("Video file not found at path: $videoPath")

        val outputFile = createOutputFile("mp4")
        try {
            val (targetHeight, videoBitrate) = when (quality.lowercase()) {
                "low" -> Pair(480, 500_000)
                "medium" -> Pair(720, 1_500_000)
                "high" -> Pair(1080, 3_000_000)
                else -> Pair(720, 1_500_000)
            }
            compressWithTransformer(videoPath, outputFile.absolutePath, targetHeight, videoBitrate, progressCallback)
            outputFile.absolutePath
        } catch (e: Exception) {
            outputFile.delete(); throw e
        }
    }

    @UnstableApi
    private suspend fun compressWithTransformer(
        inputPath: String, outputPath: String, targetHeight: Int, targetBitrate: Int,
        progressCallback: ((Float) -> Unit)? = null
    ) = suspendCancellableCoroutine<Unit> { continuation ->
        CoroutineScope(Dispatchers.Main).launch {
            try {
                val mediaItem = MediaItem.fromUri(Uri.fromFile(File(inputPath)))
                val mmr = MediaMetadataRetriever().apply { setDataSource(inputPath) }
                val originalWidth = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 1920
                val originalHeight = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 1080
                val durationMs = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
                mmr.release()

                val scaleFactor = if (originalHeight > targetHeight)
                    targetHeight.toFloat() / originalHeight.toFloat() else 1f

                val scaleEffect = ScaleAndRotateTransformation.Builder()
                    .setScale(scaleFactor, scaleFactor).setRotationDegrees(0f).build()
                val effects = Effects(emptyList(), listOf(scaleEffect))
                val editedMediaItem = EditedMediaItem.Builder(mediaItem)
                    .setRemoveAudio(false).setRemoveVideo(false).setEffects(effects).build()

                val videoEncoderSettings = VideoEncoderSettings.Builder().setBitrate(targetBitrate).build()
                val encoderFactory = DefaultEncoderFactory.Builder(context)
                    .setEnableFallback(true)
                    .setRequestedVideoEncoderSettings(videoEncoderSettings).build()

                val transformer = Transformer.Builder(context)
                    .setVideoMimeType(MimeTypes.VIDEO_H264)
                    .setEncoderFactory(encoderFactory)
                    .addListener(object : Transformer.Listener {
                        override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                            activeTransformer = null
                            progressCallback?.invoke(1.0f)
                            if (continuation.isActive) continuation.resume(Unit)
                        }
                        override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) {
                            activeTransformer = null
                            if (continuation.isActive)
                                continuation.resumeWithException(IOException("Compression failed: ${exportException.message}", exportException))
                        }
                    })
                    .build()

                activeTransformer = transformer

                if (progressCallback != null && durationMs > 0) {
                    CoroutineScope(Dispatchers.IO).launch {
                        val startTime = System.currentTimeMillis()
                        while (continuation.isActive) {
                            try {
                                if (File(outputPath).exists()) {
                                    val elapsed = System.currentTimeMillis() - startTime
                                    val est = (elapsed.toFloat() / durationMs).coerceIn(0f, 0.95f)
                                    withContext(Dispatchers.Main) { progressCallback.invoke(est) }
                                }
                                kotlinx.coroutines.delay(500)
                            } catch (e: Exception) { break }
                        }
                    }
                }

                transformer.start(editedMediaItem, outputPath)

                continuation.invokeOnCancellation {
                    CoroutineScope(Dispatchers.Main).launch {
                        try { transformer.cancel() } catch (e: Exception) { Log.e(TAG, "cancel error", e) }
                        activeTransformer = null
                    }
                }
            } catch (e: Exception) {
                activeTransformer = null
                if (continuation.isActive) continuation.resumeWithException(e)
            }
        }
    }

    private fun createOutputFile(extension: String): File =
        File(context.cacheDir, "compressed_${UUID.randomUUID()}.$extension")
}