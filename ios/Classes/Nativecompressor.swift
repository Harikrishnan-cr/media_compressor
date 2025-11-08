import Foundation
import UIKit
import AVFoundation

class NativeCompressor {
    
    // MARK: - Image Compression
    
    func compressImage(
        imagePath: String,
        quality: Int,
        maxWidth: Int?,
        maxHeight: Int?,
        result: @escaping FlutterResult
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                do {
                    let url = URL(fileURLWithPath: imagePath)
                    
                    guard FileManager.default.fileExists(atPath: url.path) else {
                        DispatchQueue.main.async {
                            result(FlutterError(
                                code: "FILE_NOT_FOUND",
                                message: "Image file not found at path: \(imagePath)",
                                details: nil
                            ))
                        }
                        return
                    }
                    
                    guard let originalImage = UIImage(contentsOfFile: url.path) else {
                        DispatchQueue.main.async {
                            result(FlutterError(
                                code: "LOAD_ERROR",
                                message: "Failed to load image from path",
                                details: nil
                            ))
                        }
                        return
                    }
                    
                    // Fix orientation properly
                    var image = self.fixOrientationProperly(image: originalImage)
                    
                    // Resize if dimensions provided
                    if let maxW = maxWidth, let maxH = maxHeight {
                        image = self.resizeImage(image: image, maxWidth: maxW, maxHeight: maxH)
                    }
                    
                    // Compress image
                    let compressionQuality = CGFloat(quality) / 100.0
                    guard let compressedData = image.jpegData(compressionQuality: compressionQuality) else {
                        DispatchQueue.main.async {
                            result(FlutterError(
                                code: "COMPRESSION_ERROR",
                                message: "Failed to compress image",
                                details: nil
                            ))
                        }
                        return
                    }
                    
                    // Save to temporary directory
                    let tempDir = NSTemporaryDirectory()
                    let fileName = "compressed_\(UUID().uuidString).jpg"
                    let outputPath = (tempDir as NSString).appendingPathComponent(fileName)
                    let outputURL = URL(fileURLWithPath: outputPath)
                    
                    try compressedData.write(to: outputURL)
                    
                    DispatchQueue.main.async {
                        result(outputPath)
                    }
                    
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "COMPRESSION_ERROR",
                            message: error.localizedDescription,
                            details: nil
                        ))
                    }
                }
            }
        }
    }
    
    // MARK: - Video Compression
    
    func compressVideo(
        videoPath: String,
        quality: String,
        result: @escaping FlutterResult
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let sourceURL = URL(fileURLWithPath: videoPath)
            
            guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "FILE_NOT_FOUND",
                        message: "Video file not found at path: \(videoPath)",
                        details: nil
                    ))
                }
                return
            }
            
            let tempDir = NSTemporaryDirectory()
            let fileName = "compressed_\(UUID().uuidString).mp4"
            let outputPath = (tempDir as NSString).appendingPathComponent(fileName)
            let outputURL = URL(fileURLWithPath: outputPath)
            
            try? FileManager.default.removeItem(at: outputURL)
            
            let preset: String
            switch quality.lowercased() {
            case "low":
                preset = AVAssetExportPresetLowQuality
            case "high":
                preset = AVAssetExportPresetHighestQuality
            case "medium":
                preset = AVAssetExportPresetMediumQuality
            default:
                preset = AVAssetExportPresetMediumQuality
            }
            
            let asset = AVURLAsset(url: sourceURL)
            
            guard let exportSession = AVAssetExportSession(
                asset: asset,
                presetName: preset
            ) else {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "EXPORT_ERROR",
                        message: "Failed to create export session",
                        details: nil
                    ))
                }
                return
            }
            
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4
            exportSession.shouldOptimizeForNetworkUse = true
            
            exportSession.exportAsynchronously {
                DispatchQueue.main.async {
                    switch exportSession.status {
                    case .completed:
                        result(outputPath)
                    case .failed:
                        result(FlutterError(
                            code: "EXPORT_FAILED",
                            message: exportSession.error?.localizedDescription ?? "Unknown export error",
                            details: nil
                        ))
                    case .cancelled:
                        result(FlutterError(
                            code: "EXPORT_CANCELLED",
                            message: "Export was cancelled",
                            details: nil
                        ))
                    default:
                        result(FlutterError(
                            code: "UNKNOWN_ERROR",
                            message: "Unknown export status: \(exportSession.status.rawValue)",
                            details: nil
                        ))
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Fix image orientation properly
    private func fixOrientationProperly(image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }
        
        guard let cgImage = image.cgImage else {
            return image
        }
        
        var transform = CGAffineTransform.identity
        
        switch image.imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: image.size.width, y: image.size.height)
            transform = transform.rotated(by: .pi)
            
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: image.size.width, y: 0)
            transform = transform.rotated(by: .pi / 2)
            
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: image.size.height)
            transform = transform.rotated(by: -.pi / 2)
            
        default:
            break
        }
        
        switch image.imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: image.size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
            
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: image.size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
            
        default:
            break
        }
        
        guard let colorSpace = cgImage.colorSpace,
              let context = CGContext(
                data: nil,
                width: Int(image.size.width),
                height: Int(image.size.height),
                bitsPerComponent: cgImage.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: cgImage.bitmapInfo.rawValue
              ) else {
            return image
        }
        
        context.concatenate(transform)
        
        switch image.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: image.size.height, height: image.size.width))
        default:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        }
        
        guard let newCGImage = context.makeImage() else {
            return image
        }
        
        return UIImage(cgImage: newCGImage)
    }
    
    /// Resize image to fit within max dimensions
    private func resizeImage(image: UIImage, maxWidth: Int, maxHeight: Int) -> UIImage {
        let size = image.size
        
        let widthRatio = CGFloat(maxWidth) / size.width
        let heightRatio = CGFloat(maxHeight) / size.height
        let ratio = min(widthRatio, heightRatio, 1.0)
        
        if ratio >= 1.0 {
            return image
        }
        
        let newSize = CGSize(
            width: size.width * ratio,
            height: size.height * ratio
        )
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}