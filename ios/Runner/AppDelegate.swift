import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var backupChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BackupExclusion") {
      backupChannel = FlutterMethodChannel(
        name: "rallycoach/backup",
        binaryMessenger: registrar.messenger())
      backupChannel?.setMethodCallHandler { call, result in
        guard call.method == "excludeFromBackup",
              let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
          result(FlutterMethodNotImplemented)
          return
        }
        var url = URL(fileURLWithPath: path)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        result(nil)
      }
    }
  }
}
