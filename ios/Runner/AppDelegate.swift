import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let iosMediaChannel = "com.atp.PhotoTagger/ios_media_saver"
  private var mediaChannelConfigured = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    configureIosMediaChannel()

    return didFinish
  }

  private func configureIosMediaChannel() {
    if mediaChannelConfigured { return }

    guard let controller = window?.rootViewController as? FlutterViewController else {
      DispatchQueue.main.async { [weak self] in
        self?.configureIosMediaChannel()
      }
      return
    }
    mediaChannelConfigured = true

    let channel = FlutterMethodChannel(
      name: iosMediaChannel,
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate missing", details: nil))
        return
      }

      switch call.method {
      case "saveImage":
        self.handleSaveMedia(call: call, result: result, resourceType: .photo)
      case "saveVideo":
        self.handleSaveMedia(call: call, result: result, resourceType: .video)
      case "getOriginalFilename":
        self.handleGetOriginalFilename(call: call, result: result)
      case "deleteAssets":
        self.handleDeleteAssets(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func handleSaveMedia(
    call: FlutterMethodCall,
    result: @escaping FlutterResult,
    resourceType: PHAssetResourceType
  ) {
    guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String,
          let filename = args["filename"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing path or filename", details: nil))
      return
    }

    let fileURL = URL(fileURLWithPath: path)

    func performSave() {
      var placeholder: PHObjectPlaceholder?
      PHPhotoLibrary.shared().performChanges({
        let request = PHAssetCreationRequest.forAsset()
        let options = PHAssetResourceCreationOptions()
        options.originalFilename = filename

        switch resourceType {
        case .photo:
          request.addResource(with: .photo, fileURL: fileURL, options: options)
        case .video:
          request.addResource(with: .video, fileURL: fileURL, options: options)
        default:
          break
        }
        placeholder = request.placeholderForCreatedAsset
      }) { success, error in
        if success, let localId = placeholder?.localIdentifier {
          result(localId)
        } else if let error = error {
          result(FlutterError(code: "SAVE_FAILED", message: error.localizedDescription, details: nil))
        } else {
          result(FlutterError(code: "SAVE_FAILED", message: "Unknown error", details: nil))
        }
      }
    }

    let currentStatus: PHAuthorizationStatus = {
      if #available(iOS 14, *) {
        return PHPhotoLibrary.authorizationStatus(for: .readWrite)
      } else {
        return PHPhotoLibrary.authorizationStatus()
      }
    }()

    func isAuthorized(_ status: PHAuthorizationStatus) -> Bool {
      if #available(iOS 14, *) {
        return status == .authorized || status == .limited
      } else {
        return status == .authorized
      }
    }

    switch currentStatus {
    case _ where isAuthorized(currentStatus):
      performSave()
    case .notDetermined:
      if #available(iOS 14, *) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
          if isAuthorized(newStatus) {
            performSave()
          } else {
            result(FlutterError(code: "NO_PERMISSION", message: "Access to photo library denied", details: nil))
          }
        }
      } else {
        PHPhotoLibrary.requestAuthorization { newStatus in
          if isAuthorized(newStatus) {
            performSave()
          } else {
            result(FlutterError(code: "NO_PERMISSION", message: "Access to photo library denied", details: nil))
          }
        }
      }
    default:
      result(FlutterError(code: "NO_PERMISSION", message: "Access to photo library denied", details: nil))
    }
  }

  private func handleGetOriginalFilename(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let assetId = args["assetId"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing assetId", details: nil))
      return
    }

    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
    guard let asset = fetchResult.firstObject else {
      result(nil)
      return
    }

    let resources = PHAssetResource.assetResources(for: asset)
    if let name = resources.first?.originalFilename {
      result(name)
    } else {
      result(nil)
    }
  }

  private func handleDeleteAssets(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let assetIds = args["assetIds"] as? [String] else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing assetIds", details: nil))
      return
    }

    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: assetIds, options: nil)
    PHPhotoLibrary.shared().performChanges({
      PHAssetChangeRequest.deleteAssets(fetchResult as NSFastEnumeration)
    }) { success, error in
      if success {
        result(true)
      } else if let error = error {
        result(FlutterError(code: "DELETE_FAILED", message: error.localizedDescription, details: nil))
      } else {
        result(false)
      }
    }
  }
}
