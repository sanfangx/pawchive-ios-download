import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let albumChannelName = "pawchive_download/album"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let albumChannel = FlutterMethodChannel(
      name: albumChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    albumChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "DEALLOCATED", message: "AppDelegate unavailable", details: nil))
        return
      }
      switch call.method {
      case "saveMediaWithCreationDate":
        self.handleSaveMedia(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func handleSaveMedia(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "Missing required 'path' argument", details: nil))
      return
    }

    guard FileManager.default.fileExists(atPath: path) else {
      result(FlutterError(code: "FILE_NOT_FOUND", message: "Media file does not exist", details: path))
      return
    }

    let isVideo = args["isVideo"] as? Bool ?? false
    let creationDate: Date?
    if let timestampNumber = args["creationTimestampMs"] as? NSNumber {
      creationDate = Date(timeIntervalSince1970: timestampNumber.doubleValue / 1000.0)
    } else {
      creationDate = nil
    }

    let fileURL = URL(fileURLWithPath: path)

    PHPhotoLibrary.shared().performChanges({
      let request = PHAssetCreationRequest.forAsset()
      let options = PHAssetResourceCreationOptions()
      options.shouldMoveFile = false
      options.originalFilename = fileURL.lastPathComponent
      request.addResource(with: isVideo ? .video : .photo, fileURL: fileURL, options: options)
      if let creationDate = creationDate {
        request.creationDate = creationDate
      }
    }) { success, error in
      DispatchQueue.main.async {
        if !success {
          result(FlutterError(
            code: "SAVE_FAILED",
            message: error?.localizedDescription ?? "Failed to save asset to Photo Library",
            details: nil
          ))
        } else {
          result(nil)
        }
      }
    }
  }
}
