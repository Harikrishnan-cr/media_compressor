import Foundation
import UIKit
import AVFoundation
import Flutter

class NativeCompressor {

    // Active export so cancel() can abort it.
    private var currentExport: AVAssetExportSession?
    // C2 fix: single-flight video guard (matches web/Android contract).
    private var videoInProgress = false
    private let lock = NSLock()

    /// Cancel any in-flight video export. Safe no-op otherwise.
    func cancelVideo() {
        currentExport?.cancelExport()
    }

    // MARK: - Image

    func compressImage(imagePath: String, quality: Int, maxWidth: Int?, maxHeight: Int?,
                       result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                do {
                    let url = URL(fileURLWithPath: imagePath)
                    guard FileManager.default.fileExists(atPath: url.path) else {
                        DispatchQueue.main.async {
                            result(FlutterError(code: "FILE_NOT_FOUND",
                                message: "Image file not found at path: \(imagePath)", details: nil))
                        }; return
                    }
                    guard let original = UIImage(contentsOfFile: url.path) else {
                        DispatchQueue.main.async {
                            result(FlutterError(code: "LOAD_ERROR",
                                message: "Failed to load image from path", details: nil))
                        }; return
                    }
                    var image = self.fixOrientation(original)
                    if let w = maxWidth, let h = maxHeight {
                        image = self.resize(image, maxWidth: w, maxHeight: h)
                    }
                    let cq = CGFloat(quality) / 100.0
                    guard let data = image.jpegData(compressionQuality: cq) else {
                        DispatchQueue.main.async {
                            result(FlutterError(code: "COMPRESSION_ERROR",
                                message: "Failed to compress image", details: nil))
                        }; return
                    }
                    let out = (NSTemporaryDirectory() as NSString)
                        .appendingPathComponent("compressed_\(UUID().uuidString).jpg")
                    try data.write(to: URL(fileURLWithPath: out))
                    DispatchQueue.main.async { result(out) }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "COMPRESSION_ERROR",
                            message: error.localizedDescription, details: nil))
                    }
                }
            }
        }
    }

    // MARK: - Video

    func compressVideo(videoPath: String, quality: String, result: @escaping FlutterResult) {
        lock.lock()
        if videoInProgress {
            lock.unlock()
            result(FlutterError(code: "BUSY", message: "Another video compression is in progress", details: nil))
            return
        }
        videoInProgress = true
        lock.unlock()

        let finish: (Any?) -> Void = { value in
            self.lock.lock(); self.videoInProgress = false; self.currentExport = nil; self.lock.unlock()
            DispatchQueue.main.async { result(value) }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let sourceURL = URL(fileURLWithPath: videoPath)
            guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                finish(FlutterError(code: "FILE_NOT_FOUND",
                    message: "Video file not found at path: \(videoPath)", details: nil)); return
            }

            let out = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("compressed_\(UUID().uuidString).mp4")
            let outURL = URL(fileURLWithPath: out)
            try? FileManager.default.removeItem(at: outURL)

            let preset: String
            switch quality.lowercased() {
            case "low": preset = AVAssetExportPresetLowQuality
            case "high": preset = AVAssetExportPresetHighestQuality
            default: preset = AVAssetExportPresetMediumQuality
            }

            let asset = AVURLAsset(url: sourceURL)
            guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
                finish(FlutterError(code: "EXPORT_ERROR",
                    message: "Failed to create export session", details: nil)); return
            }
            self.currentExport = session
            session.outputURL = outURL
            session.outputFileType = .mp4
            session.shouldOptimizeForNetworkUse = true

            session.exportAsynchronously {
                switch session.status {
                case .completed: finish(out)
                case .failed:
                    finish(FlutterError(code: "EXPORT_FAILED",
                        message: session.error?.localizedDescription ?? "Unknown export error", details: nil))
                case .cancelled:
                    finish(FlutterError(code: "CANCELLED", message: "Export was cancelled", details: nil))
                default:
                    finish(FlutterError(code: "UNKNOWN_ERROR",
                        message: "Unknown export status: \(session.status.rawValue)", details: nil))
                }
            }
        }
    }

    // MARK: - Helpers

    private func fixOrientation(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return normalized
    }

    private func resize(_ image: UIImage, maxWidth: Int, maxHeight: Int) -> UIImage {
        let size = image.size
        let ratio = min(CGFloat(maxWidth) / size.width, CGFloat(maxHeight) / size.height, 1.0)
        if ratio >= 1.0 { return image }
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}