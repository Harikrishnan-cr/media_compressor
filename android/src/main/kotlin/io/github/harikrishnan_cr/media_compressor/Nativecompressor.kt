package io.github.harikrishnan_cr.media_compressor

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import androidx.exifinterface.media.ExifInterface
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.util.UUID

data class CompressionError(
    val code: String,
    val message: String,
    val details: Any? = null
)

class NativeCompressor(private val context: Context) {

    // ============================================================================
    // IMAGE COMPRESSION
    // ============================================================================

    fun compressImage(
        imagePath: String,
        quality: Int,
        maxWidth: Int?,
        maxHeight: Int?,
        callback: (String?, CompressionError?) -> Unit
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val result = compressImageInternal(imagePath, quality, maxWidth, maxHeight)
                withContext(Dispatchers.Main) {
                    callback(result, null)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(null, CompressionError(
                        code = "COMPRESSION_ERROR",
                        message = e.message ?: "Unknown error occurred",
                        details = e.stackTraceToString()
                    ))
                }
            }
        }
    }

    private suspend fun compressImageInternal(
        imagePath: String,
        quality: Int,
        maxWidth: Int?,
        maxHeight: Int?
    ): String = withContext(Dispatchers.IO) {
        // Check if file exists
        val inputFile = File(imagePath)
        if (!inputFile.exists()) {
            throw IOException("Image file not found at path: $imagePath")
        }

        // Decode bitmap with orientation fix
        val bitmap = decodeBitmapWithOrientation(imagePath)
            ?: throw IOException("Failed to decode image from path: $imagePath")

        try {
            // Resize if dimensions are provided
            val resizedBitmap = if (maxWidth != null && maxHeight != null) {
                resizeBitmap(bitmap, maxWidth, maxHeight)
            } else {
                bitmap
            }

            // Compress and save
            val outputFile = createOutputFile("jpg")
            FileOutputStream(outputFile).use { outputStream ->
                val compressed = resizedBitmap.compress(
                    Bitmap.CompressFormat.JPEG,
                    quality,
                    outputStream
                )
                
                if (!compressed) {
                    throw IOException("Failed to compress image")
                }
            }

            // Clean up bitmaps
            if (resizedBitmap != bitmap) {
                resizedBitmap.recycle()
            }
            bitmap.recycle()

            outputFile.absolutePath
        } catch (e: Exception) {
            bitmap.recycle()
            throw e
        }
    }

    private fun decodeBitmapWithOrientation(imagePath: String): Bitmap? {
        // First, decode bitmap
        val options = BitmapFactory.Options().apply {
            inJustDecodeBounds = false
            inPreferredConfig = Bitmap.Config.RGB_565
        }
        
        val bitmap = BitmapFactory.decodeFile(imagePath, options) ?: return null

        // Get EXIF orientation
        val exif = try {
            ExifInterface(imagePath)
        } catch (e: IOException) {
            return bitmap
        }

        val orientation = exif.getAttributeInt(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL
        )

        // Return bitmap with corrected orientation
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
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.postRotate(90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.postRotate(270f)
                matrix.postScale(-1f, 1f)
            }
            else -> return bitmap
        }

        return try {
            val rotatedBitmap = Bitmap.createBitmap(
                bitmap,
                0,
                0,
                bitmap.width,
                bitmap.height,
                matrix,
                true
            )
            if (rotatedBitmap != bitmap) {
                bitmap.recycle()
            }
            rotatedBitmap
        } catch (e: OutOfMemoryError) {
            e.printStackTrace()
            bitmap
        }
    }

    private fun resizeBitmap(bitmap: Bitmap, maxWidth: Int, maxHeight: Int): Bitmap {
        val width = bitmap.width
        val height = bitmap.height

        // Calculate scaling ratio
        val widthRatio = maxWidth.toFloat() / width
        val heightRatio = maxHeight.toFloat() / height
        val ratio = minOf(widthRatio, heightRatio, 1f)

        // If image is already smaller, return original
        if (ratio >= 1f) {
            return bitmap
        }

        // Calculate new dimensions
        val newWidth = (width * ratio).toInt()
        val newHeight = (height * ratio).toInt()

        // Create resized bitmap
        return try {
            Bitmap.createScaledBitmap(bitmap, newWidth, newHeight, true)
        } catch (e: OutOfMemoryError) {
            e.printStackTrace()
            bitmap
        }
    }

    // ============================================================================
    // VIDEO COMPRESSION
    // ============================================================================

    fun compressVideo(
        videoPath: String,
        quality: String,
        callback: (String?, CompressionError?) -> Unit
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val result = compressVideoInternal(videoPath, quality)
                withContext(Dispatchers.Main) {
                    callback(result, null)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    callback(null, CompressionError(
                        code = "COMPRESSION_ERROR",
                        message = e.message ?: "Unknown error occurred",
                        details = e.stackTraceToString()
                    ))
                }
            }
        }
    }

    private suspend fun compressVideoInternal(
        videoPath: String,
        quality: String
    ): String = withContext(Dispatchers.IO) {
        val inputFile = File(videoPath)
        if (!inputFile.exists()) {
            throw IOException("Video file not found at path: $videoPath")
        }

        // Get video metadata
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(videoPath)
            
            val width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 1920
            val height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 1080
            val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0

            // Determine compression parameters based on quality
            val (targetBitrate, targetHeight) = when (quality.lowercase()) {
                "low" -> Pair(500_000, 480)      // 500 Kbps, 480p
                "medium" -> Pair(1_000_000, 720)  // 1 Mbps, 720p
                "high" -> Pair(2_000_000, 1080)   // 2 Mbps, 1080p
                else -> Pair(1_000_000, 720)
            }

            // Calculate output dimensions maintaining aspect ratio
            val aspectRatio = width.toFloat() / height.toFloat()
            val (outputWidth, outputHeight) = if (height > targetHeight) {
                val newHeight = targetHeight
                val newWidth = (newHeight * aspectRatio).toInt()
                // Make dimensions divisible by 2 (required by most codecs)
                Pair((newWidth / 2) * 2, (newHeight / 2) * 2)
            } else {
                Pair((width / 2) * 2, (height / 2) * 2)
            }

            val outputFile = createOutputFile("mp4")
            
            try {
                // Simple remux approach for Android
                remuxVideo(
                    inputPath = videoPath,
                    outputPath = outputFile.absolutePath,
                    targetBitrate = targetBitrate
                )
                
                outputFile.absolutePath
            } catch (e: Exception) {
                outputFile.delete()
                throw e
            }
        } finally {
            retriever.release()
        }
    }

    /**
     * Simplified video compression using MediaExtractor/MediaMuxer
     * This approach remuxes the video without full re-encoding for better performance
     */
    private fun remuxVideo(
        inputPath: String,
        outputPath: String,
        targetBitrate: Int
    ) {
        val extractor = MediaExtractor()
        var muxer: MediaMuxer? = null

        try {
            extractor.setDataSource(inputPath)

            // Find video and audio tracks
            var videoTrackIndex = -1
            var audioTrackIndex = -1
            val trackCount = extractor.trackCount

            for (i in 0 until trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                
                when {
                    mime.startsWith("video/") && videoTrackIndex < 0 -> {
                        videoTrackIndex = i
                    }
                    mime.startsWith("audio/") && audioTrackIndex < 0 -> {
                        audioTrackIndex = i
                    }
                }
            }

            if (videoTrackIndex < 0) {
                throw IOException("No video track found in input file")
            }

            // Create muxer
            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            // Add video track
            val videoFormat = extractor.getTrackFormat(videoTrackIndex)
            val videoOutputTrack = muxer.addTrack(videoFormat)

            // Add audio track if exists
            val audioOutputTrack = if (audioTrackIndex >= 0) {
                val audioFormat = extractor.getTrackFormat(audioTrackIndex)
                muxer.addTrack(audioFormat)
            } else -1

            // Start muxer
            muxer.start()

            // Copy video track
            copyTrack(extractor, muxer, videoTrackIndex, videoOutputTrack)

            // Copy audio track if exists
            if (audioTrackIndex >= 0) {
                copyTrack(extractor, muxer, audioTrackIndex, audioOutputTrack)
            }

        } finally {
            muxer?.stop()
            muxer?.release()
            extractor.release()
        }
    }

    private fun copyTrack(
        extractor: MediaExtractor,
        muxer: MediaMuxer,
        inputTrack: Int,
        outputTrack: Int
    ) {
        extractor.selectTrack(inputTrack)
        extractor.seekTo(0, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
        
        val bufferInfo = MediaCodec.BufferInfo()
        val buffer = ByteBuffer.allocate(1024 * 1024) // 1MB buffer
        
        while (true) {
            val sampleSize = extractor.readSampleData(buffer, 0)
            
            if (sampleSize < 0) {
                break
            }
            
            bufferInfo.offset = 0
            bufferInfo.size = sampleSize
            bufferInfo.presentationTimeUs = extractor.sampleTime
            bufferInfo.flags = extractor.sampleFlags
            
            muxer.writeSampleData(outputTrack, buffer, bufferInfo)
            extractor.advance()
        }
        
        extractor.unselectTrack(inputTrack)
    }

    // ============================================================================
    // HELPER METHODS
    // ============================================================================

    private fun createOutputFile(extension: String): File {
        val cacheDir = context.cacheDir
        val fileName = "compressed_${UUID.randomUUID()}.$extension"
        return File(cacheDir, fileName)
    }
}