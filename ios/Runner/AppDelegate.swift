import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let filePreviewChannel = FlutterMethodChannel(name: "com.local_keep/file_preview",
                                                  binaryMessenger: controller.binaryMessenger)
    
    filePreviewChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let self = self else { return }
      
      if call.method == "previewFile" {
        guard let args = call.arguments as? [String: Any],
              let filePath = args["filePath"] as? String else {
          result(FlutterError(code: "INVALID_ARGUMENT",
                            message: "File path is required",
                            details: nil))
          return
        }
        
        self.previewFile(filePath: filePath, controller: controller, result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func previewFile(filePath: String, controller: FlutterViewController, result: @escaping FlutterResult) {
    let fileURL = URL(fileURLWithPath: filePath)
    
    // Check if file exists
    guard FileManager.default.fileExists(atPath: filePath) else {
      result(FlutterError(code: "FILE_NOT_FOUND",
                        message: "File does not exist at path: \(filePath)",
                        details: nil))
      return
    }
    
    DispatchQueue.main.async {
      let documentController = UIDocumentInteractionController(url: fileURL)
      documentController.delegate = controller as? UIDocumentInteractionControllerDelegate
      
      // Present preview
      if documentController.presentPreview(animated: true) {
        result(true)
      } else {
        // If preview fails, try to present options menu
        if documentController.presentOptionsMenu(from: controller.view.bounds, in: controller.view, animated: true) {
          result(true)
        } else {
          result(FlutterError(code: "PREVIEW_FAILED",
                            message: "Cannot preview or open this file type",
                            details: nil))
        }
      }
    }
  }
}

// Extension to make FlutterViewController conform to UIDocumentInteractionControllerDelegate
extension FlutterViewController: UIDocumentInteractionControllerDelegate {
  public func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
    return self
  }
}
