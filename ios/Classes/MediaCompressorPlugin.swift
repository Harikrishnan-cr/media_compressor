import Flutter
import UIKit

public class MediaCompressorPlugin: NSObject, FlutterPlugin {

    private let compressor = NativeCompressor()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "native_compressor",
            binaryMessenger: registrar.messenger()
        )
        let instance = MediaCompressorPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "compressImage": handleCompressImage(call: call, result: result)
        case "compressVideo": handleCompressVideo(call: call, result: result)
        case "cancel": compressor.cancelVideo(); result(nil)
        case "release": handleRelease(call: call, result: result)
        default: result(FlutterMethodNotImplemented)
        }
    }

    private func handleCompressImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT",
                                message: "Path is required for image compression", details: nil)); return
        }
        let quality = args["quality"] as? Int ?? 80
        let maxWidth = args["maxWidth"] as? Int
        let maxHeight = args["maxHeight"] as? Int

        guard quality >= 0 && quality <= 100 else {
            result(FlutterError(code: "INVALID_ARGUMENT",
                                message: "Quality must be between 0 and 100", details: nil)); return
        }
        if let w = maxWidth, w <= 0 {
            result(FlutterError(code: "INVALID_ARGUMENT",
                                message: "maxWidth must be greater than 0", details: nil)); return
        }
        if let h = maxHeight, h <= 0 {
            result(FlutterError(code: "INVALID_ARGUMENT",
                                message: "maxHeight must be greater than 0", details: nil)); return
        }

        compressor.compressImage(imagePath: path, quality: quality,
                                 maxWidth: maxWidth, maxHeight: maxHeight, result: result)
    }

    private func handleCompressVideo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT",
                                message: "Path is required for video compression", details: nil)); return
        }
        let quality = args["quality"] as? String ?? "medium"
        guard ["low", "medium", "high"].contains(quality.lowercased()) else {
            result(FlutterError(code: "INVALID_ARGUMENT",
                                message: "Quality must be one of: low, medium, high", details: nil)); return
        }
        compressor.compressVideo(videoPath: path, quality: quality, result: result)
    }

    private func handleRelease(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String, !path.isEmpty else {
            result(nil); return
        }
        // C1 fix: only delete files inside the app's temporary directory.
        let tmp = (NSTemporaryDirectory() as NSString).standardizingPath
        let target = (path as NSString).standardizingPath
        if target.hasPrefix(tmp) {
            try? FileManager.default.removeItem(atPath: target)
        }
        result(nil)
    }
}